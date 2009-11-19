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
      phonetic_equivalence_class = Hash.new {[]}
      alignments.each do |alignment|
        LOGGER.debug("Compare\n" +
                     "#{alignment.source_word}\n#{alignment.dest_word}")
        # TODO Incorporate substitution threshold.
        segmentation = alignment.segmentation
        segmentation.each_morpheme_hypothesis do |morpheme_hypothesis|
          LOGGER.debug("Morpheme Hypothesis\n#{morpheme_hypothesis}")
          p = morpheme_hypothesis.key
          phonetic_equivalence_class[p] <<= morpheme_hypothesis
        end
      end
      # TODO Group allophones together in the same phonetic equivalence class.
      # Assign intersection of meanings to all the hypotheses in a phonetic
      # equivalence class.
      morpheme_hypotheses = []
      phonetic_equivalence_class.each do |p, hyps|
        morpheme_hypotheses += compile_meanings(hyps)
      end
      # TODO Add up match rates by morpheme.
      # TODO Return highest-ranked morpheme hypotheses.
      morpheme_hypotheses
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

end
