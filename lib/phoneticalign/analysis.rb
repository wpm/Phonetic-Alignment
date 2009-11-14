module PhoneticAlign

  # A morphological analysis of a word list.
  class MorphologicalAnalysis
    include Enumerable

    # WordList of words to analyze
    attr_reader :words

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
        LOGGER.debug("Align\n#{alignment}")
        alignments << alignment
      end
      alignments
    end

    def best_morpheme_hypotheses(alignments)
      morpheme_hypotheses = {}
      alignments.each do |alignment|
        segmentation = alignment.segment
        segmentation.each_morpheme_hypothesis do |morpheme_hypothesis|
          # TODO Add the hypothesis to the list.
        end
      end
      # TODO Add up match rates by morpheme.
      # TODO Return high ranked morpheme hypotheses.
      morpheme_hypotheses
    end

    def reanalyze_words(morpheme_hypotheses)
      # TODO Implement reanalyze_words
    end

  end

end
