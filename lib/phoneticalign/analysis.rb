module PhoneticAlign

  # Beam search over morphological analyses
  #
  # [<em>word_list</em>] a WordList to analyze
  # [_width_] the number of analyses to run in parallel
  # [<em>powerset_search_cutoff</em>] number of morpheme hypotheses above
  #                                   which we will not do an exhaustive
  #                                   search for semantic equivalence
  #                                   classes
  class BeamSearch
    attr_reader :beam, :completed
    
    def initialize(word_list, width, powerset_search_cutoff)
      @width = width
      @beam = [MorphologicalAnalysis.new(word_list, powerset_search_cutoff)]
      @completed = []
    end

    # Display all the analyses in the beam ranked by coverage.
    def to_s
      analyses = beam + completed
      analyses = analyses.sort
      "Beam Search: #{length + @completed.length} beams, " +
      "#{length} active\n" + analyses.join("\n\n")
    end

    # Return an analysis in the beam.
    def [](index)
      beam[index]
    end

    # The number of active beams.
    def length
      beam.length
    end

    # Get the next iteration of analyses from the currently active beam.
    def next_iteration!
      new_beam = []
      beam.each do |analysis|
        new_analyses = analysis.next_iteration
        if new_analyses.empty?
          # If there are no new analyses on this beam, move it to the
          # completed list.
          @completed << analysis
          @width -= 1
        else
          # Add the new analyses to the new beam.
          new_beam += new_analyses
        end
      end
      # Keep the top @width beams active.
      new_beam = new_beam.sort_by {|analysis| -analysis.score}
      @beam = new_beam.uniq[0...@width]
    end
    
    # Are there no more active beams?
    def done?
      beam.empty?
    end
  end


  # A morphological analysis of a word list.
  class MorphologicalAnalysis
    include Enumerable

    # WordList of words to analyze
    attr_accessor :word_list
    # Discovered Morpheme objects
    attr_accessor :morphemes
    attr_writer :score

    attr_reader :alignment_table

    # Create a morphological analysis
    #
    # [<em>word_list</em>] a WordList to analyze
    # [<em>powerset_search_cutoff</em>] number of morpheme hypotheses above
    #                                   which we will not do an exhaustive
    #                                   search for semantic equivalence
    #                                   classes
    def initialize(word_list, powerset_search_cutoff = 0)
      @word_list = word_list
      @powerset_search_cutoff = powerset_search_cutoff
      @morphemes = Set.new
      # Calculate the number of phones in the word list before we have
      # inserted any morphemes.
      @initial_phones = phones_in_word_list
      @alignment_table = AlignmentTable.new
      align_all_words
    end

    # Sort from largest score to smallest.
    def <=>(other)
      other.score <=> score
    end

    def ==(other)
      word_list == other.word_list and morphemes == other.morphemes
    end

    def eql?(other)
      self == other
    end
    
    def hash
      [word_list, morphemes].hash
    end

    # Return a deep copy of this object.
    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

    # Display a list of hypothesized morphemes followed by a list of
    # reanalyzed words.
    def to_s
      (
        ["Score #{sprintf '%0.4f', score}: " +
         "#{sprintf '%0.4f', phonetic_coverage} phonetic, " +
         "#{sprintf '%0.4f', semantic_coverage} semantic "] +
        ["Morphemes (#{morphemes.length})"] + ["-" * "Morphemes".length] +
         morphemes.to_a.sort_by {|m| m.transcription} +
         ["Word List"] + ["-" * "Word List".length] +
         word_list
       ).join("\n")
    end

    # Return the specified word in the word list.
    #
    # [<em>word_index</em>] integer index into the word list
    def [](word_index)
      word_list[word_index]
    end

    # The number of phones in the word list.
    def phones_in_word_list
      @word_list.inject(0) do |m, word|
        m += word.unanlayzed_phone_count
      end
    end

    def score
      # Cache the score in case it is expensive to generate.
      if @score.nil?
        @score = match_rate_objective
      end
      @score
    end

    # Proportion of the phones in the original word list that are part of an
    # analyzed morpheme.
    def phonetic_coverage
      1 - phones_in_word_list/@initial_phones.to_f
    end

    # Proportion of feature/value pairs in the original word list that are
    # part on an analyzed morpheme.
    def semantic_coverage
      num = 0
      den = 0
      @word_list.each do |word|
        num += word.analyzed_meaning.length
        den += word.meaning.length
      end
      num/den.to_f
    end

    # This is the main loop of the analysis proceedure.
    def next_iteration
      morpheme_hypotheses = hypothesize_morphemes
      return [] if morpheme_hypotheses.empty?
      equivalence_classes = collect_morpheme_hypotheses(morpheme_hypotheses)
      new_morphemes = equivalence_classes.new_morphemes
      insert_morphemes_into_analyses(new_morphemes)
    end

    # The alignments between all word pairs given the morphemes in this
    # analysis.
    def alignments
      @alignment_table.indexes.keys
    end

    # Get morpheme hypotheses from the alignments.
    def hypothesize_morphemes
      morpheme_hypotheses = []
      alignments.each do |alignment|
        LOGGER.debug("Compare\n" +
                     "#{alignment.source_word}\n#{alignment.dest_word}")
        # TODO Incorporate substitution threshold.
        segmentation = alignment.segmentation
        LOGGER.debug("Segmentation\n#{segmentation}")
        segmentation.each_morpheme_hypothesis do |morpheme_hypothesis|
          LOGGER.debug("Morpheme Hypothesis\n#{morpheme_hypothesis}")
          morpheme_hypotheses << morpheme_hypothesis
        end
      end
      morpheme_hypotheses
    end

    # Partition the morpheme hypotheses into equivalence classes based on
    # phonetic and then semantic compatibility.
    #
    # [<em>morpheme_hypotheses</em>] list of morpheme hypotheses
    def collect_morpheme_hypotheses(morpheme_hypotheses)
      MorphemeHypothesisEquivalenceClasses.new(morpheme_hypotheses,
                                               @powerset_search_cutoff)
    end

    # Create a new copy of this analysis with the hypothesized morphemes
    # inserted.
    #
    # [<em>new_morphemes</em>] new morpheme and morpheme hypotheses
    def insert_morphemes_into_analyses(new_morphemes)
      new_morphemes.map do |m|
        morpheme = m.morpheme
        morpheme_hypotheses = m.morpheme_hypotheses
        LOGGER.debug("New morpheme: #{morpheme}")
        analysis = self.deep_copy
        analysis.morphemes << morpheme
        analysis.reanalyze_words(morpheme_hypotheses)
        LOGGER.debug("New analysis\n#{analysis}")
        analysis
      end
    end

    # Rank morpheme hypothesis sets by the sum of their match rates.
    def match_rate_objective
      alignments.inject(0) { |r, alignment| r += alignment.match_rate }
    end

    # Insert the specified morpheme hypotheses into the phonetic components of
    # their words.
    def reanalyze_words(morpheme_hypotheses)
      # Create a table of morpheme hypotheses indexed by word.
      word_table = {}
      morpheme_hypotheses.each do |hyp|
        # TODO Check for overlapping morpheme ranges with asserts.
        if not word_table.has_key?(hyp.original_word)
          word_table[hyp.original_word] = []
        end
        word_table[hyp.original_word] <<= hyp
      end
      # Insert the new morphemes into the phonetic components of the original
      # words.
      changed_word_indexes = []
      word_table.each do |word, hyps|
        # Don't insert a morpheme at the same location more than once.
        hyps.uniq!
        # Sort the morphemes in reverse order.  That way inserting the first
        # one doesn't change the offsets of the subsequent ones.
        hyps = hyps.sort_by {|hyp| -hyp.original_word_offsets[0] }
        # Insert the new morphemes into the specified positions in the words'
        # phonetic components.  Make the changes to the word stored in this
        # analysis' word list so that we may maintain multiple independent
        # analyses.
        hyps.each do |hyp|
          source_index, dest_index = @alignment_table.indexes[hyp.alignment]
          word_index = case hyp.word
          when :source
            source_index
          when :dest
            dest_index
          else
            raise RuntimeError.new("Invalid word value #{word}")
          end
          original_word = word_list[word_index]
          from, to = hyp.original_word_offsets
          LOGGER.debug("Insert #{hyp.morpheme} into " +
                       "#{original_word.transcription}[#{from}..#{to}]")
          original_word.phonetic_component[from..to] = hyp.morpheme
          changed_word_indexes << word_index
        end
      end
      # Delete alignments involving words that changed.
      changed_word_indexes.each { |index| @alignment_table.delete(index) }
      # Rerun alignments for the words that changed.
      changed_word_indexes.each do |word_index|
        # The alignments are done so that source words always have larger
        # indexes than dest words.
        0.upto(word_index - 1) do |dest_index|
          source_word = self[word_index]
          dest_word = self[dest_index]
          alignment = Alignment.new(source_word, dest_word)
          @alignment_table.add(alignment, word_index, dest_index)
        end
        (word_index + 1).upto(word_list.length - 1) do |source_index|
          source_word = self[source_index]
          dest_word = self[word_index]
          alignment = Alignment.new(source_word, dest_word)
          @alignment_table.add(alignment, source_index, word_index)
        end
      end
    end

    protected

    # Generate alignments for all the word pairs in the list that have
    # overlapping semantics.
    def align_all_words
      0.upto(word_list.length-1) do |i|
        0.upto(i-1) do |j|
          w1 = self[i]
          w2 = self[j]
          if (w1.meaning & w2.meaning).empty?
            LOGGER.debug("Skipping alignment for\n" +
                         "#{w1}\n#{w2}\nbecause they share no meaning")
            next
          end
          @alignment_table.add(Alignment.new(w1, w2), i, j)
        end
      end
    end

  end


  # Two-way lookup table of Alignment objects and their corresponding source
  # and dest word index pairs.
  class AlignmentTable
    # Table of [source, dest] word index pairs by Alignment
    attr_reader :indexes
    # Table of Alignment objects by word index
    attr_reader :alignments

    def initialize
      @indexes = {}
      @alignments = {}
    end

    def to_s
      (table_to_lines(alignments) + table_to_lines(indexes)).join("\n")
    end

    def inspect
      "AlignmentTable: #{alignments.length} alignments, " +
      "#{indexes.length} words"
    end

    # Add an Alignment and its word indexes to the table.
    def add(alignment, source_index, dest_index)
      @indexes[alignment] = [source_index, dest_index]
      [source_index, dest_index].each do |index|
        @alignments[index] = alignments.fetch(index, Set.new) << alignment
      end
    end

    # Delete all the alignments involving the word with the specified index.
    def delete(index)
      @alignments.delete(index).each do |alignment|
        @indexes.delete(alignment)
      end
    end

    protected

    def table_to_lines(table)
      table.keys.sort.inject([]) do |lines, key|
        lines << key.inspect
        lines << table[key].sort.map { |value| value.inspect }.join(",")
      end
    end

  end


  # Table of morpheme hypotheses indexed first by phonetic and then by
  # semantic equivalence.
  class MorphemeHypothesisEquivalenceClasses < Hash
    # Partition the morpheme hypotheses into phonetic and semantic equivalence
    # classes.
    #
    # [<em>morpheme_hypotheses</em>] sequence of MorphemeHypothesis objects to
    #                                partition
    # [<em>powerset_search_cutoff</em>] size of an allomorph set above which
    #                                    we will not do a powerset search for
    #                                    the semantic equivalence classes
    def initialize(morpheme_hypotheses, powerset_search_cutoff)
      group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      group_into_semantic_equivalence_classes!(powerset_search_cutoff)
    end

    # The morpheme hypothesese grouped by phonetic and then semantic
    # equivalence class with the allomorph set displayed above the phonetic
    # class.
    def to_s
      map do |allomorphs, hyps|
        separator = "-"* allomorphs.to_s.length
        "#{allomorphs}\n#{separator}\n" + hyps.flatten.join("\n")
      end.join("\n\n")
    end

    # Return a list of the sets of equivalent morpheme hypotheses based on the
    # sum of the match rates of the alignments in which they appear.
    def new_morphemes
      new_morphemes = []
      each_equivalence_class do |allomorphs, hyps|
        morpheme = Morpheme.new(allomorphs, hyps.first.meaning)
        new_morphemes <<
          Struct.new(:morpheme,
                     :morpheme_hypotheses).new(morpheme, hyps)
      end
      new_morphemes
    end

    # Enumerate over the equivalence classes created by partitioning.
    def each_equivalence_class
      # TODO Make this the default each function of an Enumerable object?
      each do |allomorphs, semantic_equivalence_classes|
        semantic_equivalence_classes.each do |morpheme_hypotheses|
          yield [allomorphs, morpheme_hypotheses]
        end
      end
    end

    protected

    # Create a hash of morpheme hypothesis lists indexed by compatible
    # allomorph sets.
    #
    # When this function exits, the keys of this table will be allomorph sets
    # and the values will be lists of corresponding morpheme hypotheses.
    def group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      morpheme_hypotheses.each do |morpheme_hypothesis|
        compatible = keys.find_all do |allomorphs|
          allomorphs.is_compatible?(morpheme_hypothesis.allomorphs)
        end
        case compatible.length
        when 0
          self[morpheme_hypothesis.allomorphs] = [morpheme_hypothesis]
        when 1
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        else
          # TODO Need a principled reason for picking one class over another
          # when multiple ones are compatible.
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        end
      end
    end

    # Add a new morpheme hypothesis to the table indexed by allomorphs.  If
    # the new hypothesis' allomorph set is larger than the key currently in
    # the table, use it instead.
    def add_hypothesis_to_phonetic_class!(key, morpheme_hypothesis)
      new_allomorphs = morpheme_hypothesis.allomorphs
      if new_allomorphs.length > key.length
        self[new_allomorphs] = self[key]
        self.delete(key)
        key = new_allomorphs
      end
      self[key] << morpheme_hypothesis
    end

    # Subdivide each set of morpheme hypotheses in a phonetic equivalence
    # class into a semantic equivalence classes based on meaning
    # intersections.
    #
    # [<em>powerset_search_cutoff</em>] size of an allomorph set above which
    #                                    we will not do a powerset search for
    #                                    the semantic equivalence classes
    def group_into_semantic_equivalence_classes!(powerset_search_cutoff)
      each do |allomorphs, hyps|
        LOGGER.debug("Compile semantic equivalence class for "+
                     "#{allomorphs} (#{self[allomorphs].length} hypotheses)")
        # If there is an meaning intersection between all the hypotheses,
        # create a single semantic equivalence class.
        meaning = shared_meaning(hyps)
        self[allomorphs] = if not meaning.empty?
          LOGGER.debug("Use shared meaning #{meaning}.")
          [assign_meaning(hyps, meaning)]
        elsif self[allomorphs].length <= powerset_search_cutoff
          # If the hypothesis set for these allomorphs is small enough,
          # exhaustively search its powerset for shared meanings.
          LOGGER.debug("Find shared meanings with powerset search.")
          powerset_compile_meanings(hyps)
        else
          LOGGER.debug("No shared meaning.")
          []
        end
      end
    end

    # Partition a list of morpheme hypotheses with the same phonetic component
    # into the largest intersecting meaning sets.
    #
    # Enumerate over the subsets of the list of morpheme hypotheses in order
    # from largest to smallest.  When a subset that share some meaning is
    # found, assign that intersected meaning to all the hypotheses in the
    # subset, and move those hypotheses onto a compiled morpheme hypotheses
    # list. Repeat until all hypotheses have been moved onto the compiled
    # morpheme hypotheses list.
    #
    # [<em>morpheme_hypotheses</em>] list of morpheme hypotheses with the same
    #                                phonetic component
    def powerset_compile_meanings(morpheme_hypotheses)
      compiled_morpheme_hypotheses = []
      while not morpheme_hypotheses.empty?
        # Find the largest subset of the morpheme hypotheses that share meaning.
        shared = nil
        meaning_partition = morpheme_hypotheses.powerset_by_length.find do |partition|
          shared = shared_meaning(partition)
          not shared.empty?
        end
        if not meaning_partition.nil?
          # Assign the shared meaning to all the morpheme hypotheses in the
          # partition and move these to the compiled morpheme hypothesis list.
          morpheme_hypotheses -= meaning_partition
          meaning_partition = assign_meaning(meaning_partition, shared)
          compiled_morpheme_hypotheses += [meaning_partition]
        else
          # There are no more meaning intersections.  Move all the remaining
          # hypotheses to the compiled morpheme hypothesis list.
          compiled_morpheme_hypotheses +=
            morpheme_hypotheses.map { |hyp| [hyp] }
          morpheme_hypotheses = []
        end
      end
      compiled_morpheme_hypotheses
    end

    # The meaning shared among a group of morpheme hypotheses.
    #
    # This returns the intersection of the meanings of all the morpheme
    # hypotheses passed to it.
    #
    # [_hyps_] a list of morpheme hypotheses
    def shared_meaning(hyps)
      hyps.inject(hyps.first.meaning) do |meaning, hyp|
        meaning &= hyp.meaning
      end
    end

    # Assign a meaning to a group of morpheme hypotheses
    #
    # [_hyps_] a list of morpheme hypotheses
    # [_meaning_] the meaning to assign to the morpheme in each of the
    #             hypotheses
    def assign_meaning(hyps, meaning)
      hyps.map { |hyp| hyp.meaning = meaning }
      hyps
    end

  end


end
