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

    # List of segment boundary offsets
    attr_reader :segment_boundaries

    def initialize(word1, word2)
      @segment_boundaries = []
      super(word1.phonetic_component.clone, word2.phonetic_component.clone)
    end

    # The string representation of the alignment consists of four lines:
    #
    # 1. The source array
    # 2. The destination array
    # 3. An annotation line with S, I, D or nothing for aligned elements.
    # 4. The edit distance
    def to_s
      # Create the source and destination lines.
      s_line = source_alignment('-').map do |s|
        s.respond_to?(:transcription) ? s.transcription : s.to_s
      end
      d_line = dest_alignment('-').map do |s|
        s.respond_to?(:transcription) ? s.transcription : s.to_s
      end
      # Create short pneumonics for the edit operations.
      ops = edit_operations.map do |op|
        case op
        when nil
          c = " "
        when :substitute
          c = "S"
        when :insert
          c = "I"
        when :delete
          c = "D"
        end
      end
      # Insert segment boundary markers.
      segment_boundaries.each_with_index do |b, i|
        index = b + i
        [s_line, d_line, ops].each { |l| l.insert(index, "|") }
      end
      # Find the longest element in all the lines.
      longest = [s_line, d_line, ops].map do |l|
        l.map{|e| e.jlength}.max
      end.max
      # Center each array element over a field of that width.
      lines = [s_line, d_line, ops].map do |list|
        list.map{|c| c.center(longest)}.join
      end
      (lines + [(sprintf "%0.4f", match_rate)]).join("\n")
    end

    # Alignment match rate
    #
    # The match rate is a number from 0 to 1 that measures the similarity of
    # the two aligned words.
    def match_rate
      # TODO Different match rate for morphemes.
      ops = edit_operations
      match = 0
      ops.each { |op| match += 1 if op.nil? }
      match/ops.length.to_f
    end

    # Insert segment boundaries into the alignment.
    #
    # Segment boundaries are inserted between every pair of alignment slots
    # that have different edit operations.  Phone substitutions less than or
    # equal to a threshold are treated as matching for the purposes of
    # segmentation.
    #
    # [<em>substitution_threshold</em>] difference beneath which phone
    #                                   subsitutions are treated as matching
    def segment!(substitution_threshold = 0)
      ops = edit_operations
      # Treat phone substitutions that are close enough as matching.
      word1 = source_alignment
      word2 = dest_alignment
      ops.each_with_index do |op, i|
        if op == :substitute and
           word1[i].kind_of?(Phone) and word2[i].kind_of?(Phone) and
           (word1[i] - word2[i]) <= substitution_threshold
          ops[i] = nil
        end
      end
      # Insert boundaries at edit operation discontinuities.
      1.upto(ops.length-1) do |i|
        @segment_boundaries << i if not ops[i] == ops[i-1]
      end
    end

    def each_meaning_constraint
      # TODO Implement each_meaning_constraint
    end

    # Get the edit operations and cache the result.
    def edit_operations
      @edit_operations_cache = super if @edit_operations_cache.nil?
      @edit_operations_cache
    end

    protected

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
