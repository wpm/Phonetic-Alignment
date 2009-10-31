require "editalign"

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

    def align_words
      alignments = []
      @word_list.each_symmetric_pair do |w1, w2|
        alignments << Alignment.new(w1, w2)
      end
      alignments
    end

    def best_morpheme_hypotheses(alignments)
      morpheme_hypotheses = {}
      alignments.each do |alignment|
        alignment.segment!
        alignment.each_meaning_constraint do |constraint|
          # TODO Add the constraint to the list.
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


  # An edit-distance alignment between the phonetic components of two words.
  class Alignment < EditAlign::Alignment
    INFINITY = 1.0/0

    def initialize(word1, word2)
      @segment_boundaries = []
      super(word1.phonetic_component.clone, word1.phonetic_component.clone)
    end

    # Insert segment boundaries into the alignment.
    def segment!
      # TOTO Implement segment
    end

    # The substitution cost function used to perform alignments.
    #
    # The cost of substituting one segment for another in an alignment is
    # equal to the distance between them.
    #
    # [_item1_] a Phone or Morpheme
    # [_item2_] a Phone or Morpheme
    #
    # This function is called by the parent class.
    def substitute(item1, item2)
      if item1 == item2
        0
      elsif item1.nil? or item2.nil?
        # Insertions and deletions have a cost of 1.
        1
      elsif item1.is_a?(Morpheme) and item2.is_a?(Morpheme)
        # Morphemes only align with compatible morphemes.
        item1.is_compatible?(item2) ? 0 : INFINITY
      elsif item1.is_a?(Phone) and item2.is_a?(Phone)
        # The substitution cost of non-equal phones is a function of their
        # phonetic distance.
        # TODO Scale by substitution penalty.
        item1 - item2
      else
        # Phones and morphemes never align.
        INFINITY
      end
    end

  end


end
