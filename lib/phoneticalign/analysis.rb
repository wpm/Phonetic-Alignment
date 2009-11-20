module PhoneticAlign

  # A morphological analysis of a word list.
  class MorphologicalAnalysis
    include Enumerable

    # WordList of words to analyze
    attr_reader :words

    # Create an analysis
    #
    # [<em>word_list</em>] a WordList to analyze
    def initialize(word_list)
      @word_list = word_list
    end

    # Enumerate iterations of the analysis.  This is the top-level loop of the
    # morphological analysis procedure.
    def each
      morphemes = Set.new
      until @word_list.all? { |word| word.fully_analyzed? }
        alignments = align_words
        morpheme_hypotheses = best_morpheme_hypotheses(alignments)
        break if morpheme_hypotheses.emtpy?
        reanalyze_words(morpheme_hypotheses)
        morphemes += morpheme_hypotheses
      end
    end

    # Generate alignments for all the word pairs in the list that have
    # overlapping semantics.
    def align_words
      alignments = []
      @word_list.each_symmetric_pair do |w1, w2|
        if (w1.meaning & w2.meaning).empty?
          LOGGER.debug("Skipping alignment for\n#{w1}\n#{w2}")
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
      # Get morpheme hypotheses from the alignments and group them into
      # phonetic equivalence classes.
      morpheme_hypotheses = MorphemeHypothesisEquivalenceClasses.new
      alignments.each do |alignment|
        LOGGER.debug("Compare\n" +
                     "#{alignment.source_word}\n#{alignment.dest_word}")
        # TODO Incorporate substitution threshold.
        segmentation = alignment.segmentation
        segmentation.each_morpheme_hypothesis do |morpheme_hypothesis|
          LOGGER.debug("Morpheme Hypothesis\n#{morpheme_hypothesis}")
          morpheme_hypotheses << morpheme_hypothesis
        end
      end
      # TODO Group allophones together in the same phonetic equivalence class.
      # TODO Assign intersection of meanings to all the hypotheses in a phonetic equivalence class.
      morpheme_hypotheses.partition!
      # TODO Add up match rates by morpheme.
      # TODO Return highest-ranked morpheme hypotheses.
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
    def compile_meanings(morpheme_hypotheses)
      compiled_morpheme_hypotheses = []
      while not morpheme_hypotheses.empty?
        # Find the largest subset of the morpheme hypotheses that share meaning.
        shared_meaning = nil
        meaning_partition = morpheme_hypotheses.powerset_by_length.find do |partition|
          shared_meaning =
          partition.inject(partition.first.meaning) do |meaning, hyp|
            meaning &= hyp.meaning
          end
          not shared_meaning.nil?
        end
        if not meaning_partition.nil?
          # Assign the shared meaning to all the morpheme hypotheses in the
          # partition and move these to the compiled morpheme hypothesis list.
          morpheme_hypotheses -= meaning_partition
          meaning_partition.map do |hyp|
            hyp.meaning = shared_meaning
          end
          compiled_morpheme_hypotheses += meaning_partition
        else
          # There are no more meaning intersections.  Move all the remaining
          # hypotheses to the compiled morpheme hypothesis list.
          compiled_morpheme_hypotheses += morpheme_hypotheses
          morpheme_hypotheses = []
        end
      end
      compiled_morpheme_hypotheses
    end

    def reanalyze_words(morpheme_hypotheses)
      # TODO Implement reanalyze_words
    end

  end


  class MorphemeHypothesisEquivalenceClasses < Hash
    def initialize
      @morpheme_hypotheses = []
    end
    
    def <<(morpheme_hypothesis)
      @morpheme_hypotheses << morpheme_hypothesis
    end

    def to_s
      if not @morpheme_hypotheses.empty?
        @morpheme_hypotheses.sort_by {|h| h.match_rate}.join("\n\n")
      else
        map do |allophones, hyps|
          allophones_s = allophones.map do |allophone|
            allophone.map { |phone| phone.transcription }.join("")
          end.join("/")
          allophones_s + "\n" + "-"* allophones_s.length + "\n" + hyps.join("\n")
        end.join("\n\n")
      end
    end
    
    def partition!
      group_into_phonetic_equivalence_classes!
      group_into_semantic_equivalence_classes!
      self
    end
    
    # Create a hash of morpheme hypothesis lists indexed by compatible
    # allophone sets.
    def group_into_phonetic_equivalence_classes!
      @morpheme_hypotheses.each do |morpheme_hypothesis|
        compatible = keys.find_all do |allophones|
          compatible_allophones?(allophones, morpheme_hypothesis.allophones)
        end
        case compatible.length
        when 0
          self[morpheme_hypothesis.allophones] = [morpheme_hypothesis]
        when 1
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        else
          # TODO Need a pricipled reason for picking one class over another
          # when multiple ones are compatible.
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        end
      end
      @morpheme_hypotheses = []
    end

    def group_into_semantic_equivalence_classes!
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

    # Two allophone sets are compatible if one is a subset of the other.
    def compatible_allophones?(a ,b)
      a.subset?(b) or b.subset?(a)
    end

    def allophones_to_s(allophones)
      allophones.map do |allophone|
        allophone.map { |phone| phone.transcription }.join("")
      end.join("/")
    end

  end


end
