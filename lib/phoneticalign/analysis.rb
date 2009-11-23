module PhoneticAlign

  # A morphological analysis of a word list.
  class MorphologicalAnalysis
    include Enumerable

    # WordList of words to analyze
    attr_reader :word_list
    # Discovered Morpheme objets
    attr_reader :morphemes

    # Create a morphological analysis
    #
    # [<em>word_list</em>] a WordList to analyze
    def initialize(word_list, powerset_search_cutoff = nil)
      @word_list = word_list
      @powerset_search_cutoff = powerset_search_cutoff.nil? ?
        POWERSET_SEARCH_CUTOFF : powerset_search_cutoff
      @morphemes = []
    end

    # Display a list of hypothesized morphemes followed by a list of
    # reanalyzed words.
    def to_s
      (["Morphemes"] + ["-" * "Morphemes".length] +
       morphemes +
       ["Word List"] + ["-" * "Word List".length] +
       word_list).join("\n")
    end

    # Run the next iteration of the analysis.  This is the top-level loop of
    # the morphological analysis procedure.
    #
    # This returns nil when the analysis is complete and self when it is not.
    def next_iteration
      alignments = align_words
      allophones, meaning, morpheme_hypotheses = 
        best_morpheme_hypotheses(alignments)
      return nil if morpheme_hypotheses.empty?
      new_morpheme = Morpheme.new(allophones, meaning)
      LOGGER.info("New morpheme: #{new_morpheme}")
      @morphemes << new_morpheme
      reanalyze_words(morpheme_hypotheses)
      LOGGER.info("Reanalyzed word list\n#{word_list}")
      # TODO Return a list of copies of this object to do a beam search.
      self
    end

    # Generate alignments for all the word pairs in the list that have
    # overlapping semantics.
    def align_words
      alignments = []
      @word_list.each_symmetric_pair do |w1, w2|
        if (w1.meaning & w2.meaning).empty?
          LOGGER.debug("Skipping alignment for\n" +
                       "#{w1}\n#{w2}\nbecause they share no meaning")
          next
        end
        alignment = Alignment.new(w1, w2)
        alignments << alignment
      end
      alignments
    end

    # Get a list of the best morpheme hypotheses in a given set of alignments.
    #
    # [_alignments_] sequence of Alignment objects
    def best_morpheme_hypotheses(alignments)
      # Get morpheme hypotheses from the alignments.
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
      # Partition the morpheme hypotheses into equivalence classes based on
      # phonetic and then semantic compatibility.
      equivalence_classes =
        MorphemeHypothesisEquivalenceClasses.new(morpheme_hypotheses,
                                                 @powerset_search_cutoff)
      # Return the highest-ranked set of equivalent morpheme hypotheses based
      # on the sum of the match rates of the alignments in which they appear.
      equivalence_classes.best_class do |hyps|
        hyps.inject(0) { |r, hyp| r += hyp.match_rate  }
      end
    end

    # Insert the specified morpheme hypotheses into the phonetic components of
    # their words.
    def reanalyze_words(morpheme_hypotheses)
      # Create a table of morpheme hypotheses indexed by word.
      word_table = Hash.new {[]}
      morpheme_hypotheses.each do |hyp|
        # TODO Check for overlapping morpheme ranges with asserts.
        word_table[hyp.original_word] <<= hyp
      end
      # Insert the new morphemes into the phonetic components of the original
      # words.
      word_table.each do |word, hyps|
        # Don't insert a morpheme at the same location more than once.
        hyps.uniq!
        # Sort the morphemes in reverse order.  That way inserting the first
        # one doesn't change the offsets of the subsequent ones.
        hyps = hyps.sort_by {|hyp| -hyp.original_word_offsets[0] }
        # Insert the new morphemes into the specified positions in the words'
        # phonetic components.
        hyps.each do |hyp|
          from, to = hyp.original_word_offsets
          LOGGER.debug("Insert #{hyp.morpheme} into " +
                       "#{hyp.original_word.transcription}[#{from}..#{to}]")
          hyp.original_word.phonetic_component[from..to] = hyp.morpheme
        end
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
    # [<em>powerset_search_cutoff</em>] size of an allophone set above which
    #                                    we will not do a powerset search for
    #                                    the semantic equivalence classes
    def initialize(morpheme_hypotheses, powerset_search_cutoff)
      group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      group_into_semantic_equivalence_classes!(powerset_search_cutoff)
    end

    # The morpheme hypothesese grouped by phonetic and then semantic
    # equivalence class with the allophone set displayed above the phonetic
    # class.
    def to_s
      map do |allophones, hyps|
        separator = "-"* allophones.to_s.length
        "#{allophones}\n#{separator}\n" + hyps.flatten.join("\n")
      end.join("\n\n")
    end

    # Return the best morpheme hypothesis equivalence class based on a scoring
    # function provided by the caller.
    #
    # [<em>scoring_function</em>] a block that takes a list of
    #                             MorphemeHypothesis objects and returns a
    #                             number greater than zero
    def best_class(&scoring_function)
      partition! if not @morpheme_hypotheses.nil?
      score = 0
      best_meaning = []
      best_allophones = []
      best_hypotheses = []
      each_equivalence_class do |allophones, morpheme_hypotheses|
        new_score = scoring_function.call(morpheme_hypotheses)
        LOGGER.debug("#{sprintf '%0.4f', new_score}\t" +
                     "#{allophones}:#{morpheme_hypotheses.first.meaning}")
        if new_score >= score
          score = new_score
          best_meaning = morpheme_hypotheses.first.meaning
          best_allophones = allophones
          best_hypotheses = morpheme_hypotheses
        end
      end
      [best_allophones, best_meaning, best_hypotheses]
    end

    protected

    # Enumerate over the equivalence classes created by partitioning.
    def each_equivalence_class
      each do |allophones, semantic_equivalence_classes|
        semantic_equivalence_classes.each do |morpheme_hypotheses|
          yield [allophones, morpheme_hypotheses]
        end
      end
    end

    # Create a hash of morpheme hypothesis lists indexed by compatible
    # allophone sets.
    #
    # When this function exits, the keys of this table will be allophone sets
    # and the values will be lists of corresponding morpheme hypotheses.
    def group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      morpheme_hypotheses.each do |morpheme_hypothesis|
        compatible = keys.find_all do |allophones|
          allophones.is_compatible?(morpheme_hypothesis.allophones)
        end
        case compatible.length
        when 0
          self[morpheme_hypothesis.allophones] = [morpheme_hypothesis]
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

    # Add a new morpheme hypothesis to the table indexed by allophones.  If
    # the new hypothesis' allophone set is larger than the key currently in
    # the table, use it instead.
    def add_hypothesis_to_phonetic_class!(key, morpheme_hypothesis)
      new_allophones = morpheme_hypothesis.allophones
      if new_allophones.length > key.length
        self[new_allophones] = self[key]
        self.delete(key)
        key = new_allophones
      end
      self[key] << morpheme_hypothesis
    end

    # Subdivide each set of morpheme hypotheses in a phonetic equivalence
    # class into a semantic equivalence classes based on meaning
    # intersections.
    #
    # [<em>powerset_search_cutoff</em>] size of an allophone set above which
    #                                    we will not do a powerset search for
    #                                    the semantic equivalence classes
    def group_into_semantic_equivalence_classes!(powerset_search_cutoff)
      each do |allophones, hyps|
        LOGGER.debug("Compile semantic equivalence class for "+
                     "#{allophones} (#{self[allophones].length} hypotheses)")
        # If there is an meaning intersection between all the hypotheses,
        # create a single semantic equivalence class.
        meaning = shared_meaning(hyps)
        self[allophones] = if not meaning.empty?
          LOGGER.debug("Use shared meaning.")
          [assign_meaning(hyps, meaning)]
        elsif self[allophones].length <= powerset_search_cutoff
          # If the hypothesis set for these allophones is small enough,
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
