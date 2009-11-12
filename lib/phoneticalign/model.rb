require "editalign"
require "set"

module PhoneticAlign

  # A pairing of features and values.
  #
  # This is a hash that defines intersection and difference operators.
  class FeatureValueMatrix < Hash

    # Create a feature matrix from a hash table.
    def FeatureValueMatrix.from_hash(h)
      FeatureValueMatrix[*h.to_a.flatten]
    end

    # Intersection operator
    #
    # Return a feature matrix containing all the feature value pairs that are
    # the same in this and the other matrix.
    def &(other)
      self.class[*select { |f, v| self[f] == other[f] }.flatten]
    end

    # Addition operator
    #
    # Return a feature matrix that is the union of the feature value pairs in
    # the operands.  Raise an ArgumentError is there is a value mismatch for a
    # shared feature.
    def +(other)
      sum = clone
      other.each do |f,v|
        if sum.has_key?(f) and not sum[f] == v
          raise ArgumentError.new("Mismatched feature "+
                                  "'#{f}': '#{sum[f]}'/'#{v}'")
        end
        sum[f] = v
      end
      sum
    end

    # Difference operator
    #
    # Return a feature matrix containing all the feature value pairs that are
    # in in this matrix and not the same in the other one.
    def -(other)
      self.class[*select { |f, v| not self[f] == other[f] }.flatten]
    end

    # A single line of comma-delimited <em>feature = value</em> pairs sorted
    # alphabetically by feature and surrounded by square brackets.
    def to_s
      "[" + sort_by {|f,v| f.to_s }.collect do |f,v|
        "#{f} = #{v}"
      end.join(", ") + "]"
    end

    def inspect
      to_s
    end

  end


  # A phone is a pairing of an IPA symbol and a matrix of phonetic features.
  class Phone
    # An IPA character
    attr_reader :ipa
    # A FeatureValueMatrix describing the phonetic features
    attr_reader :features

    def initialize(ipa, features = FeatureValueMatrix.new)
      @ipa = ipa
      @features = features
    end

    # Phones are equal if they have the same IPA character and features.
    #
    # This function returns false if other is not a kind of Phone.  We do
    # explicit type checking here instead of relying on duck typing because
    # the edit alignment algorithm will compare phones and morphemes.
    def ==(other)
      other.kind_of?(Phone) and
      ipa == other.ipa and
      features == other.features
    end

    # The number of features in which two phones differ divided by the number
    # of features in this phone.
    #
    # This operation is symmetrical if both phones have the same set of
    # features.
    #
    # If either of the phones does not have features, the function returns 0
    # if their IPA transcriptions are equal and 1 otherwise.
    def -(other)
      if features.empty? or other.features.empty?
        ipa == other.ipa ? 0 : 1
      else
        (features - other.features).length/features.length.to_f
      end
    end

    # The IPA chracter followed by the feature matrix
    #
    # [<em>ipa_field_width</em>] optional field width for the IPA character;
    #                            if unspecified the character length is used
    #
    # The <em>ipa_field_width</em> is used by PhoneTable to keep the IPA
    # characters in a table aligned.
    def to_s(ipa_field_width = nil)
      ipa_s = ipa_field_width.nil? ?
              ipa : sprintf("%-#{ipa_field_width}s", transcription)
      "#{ipa_s} #{features}"
    end

    def inspect
      to_s
    end

    # The IPA character
    def transcription
      ipa.to_s
    end
  end


  # A morpheme is a pairing of a set of allphones and a meaning.
  class Morpheme
    # A set of sequences of Phone objects
    attr_reader :allophones
    # A FeatureValueMatrix representing the meaning
    attr_reader :meaning

    # Create the morpheme from an allophone set and a meaning.
    #
    # An allophone is a sequence of phones.
    #
    # [_allophones_] sequence of allophones
    # [_meaning_] the meaning
    def initialize(allophones, meaning)
      allophones = Set.new(allophones) if not allophones.is_a?(Set)
      @allophones = allophones
      @meaning = meaning
    end

    # Morphemes are equal if they are compatible.
    #
    # This function returns false if other is not a kind of Morpheme.  We do
    # explicit type checking here instead of relying on duck typing because
    # the edit alignment algorithm will compare phones and morphemes.
    def ==(other)
      other.kind_of?(Morpheme) and is_compatible?(other)
    end

    # Two morphemes are compatible if they have the same meaning and the
    # allophones of one are a subset of the allophones of the other.
    def is_compatible?(other)
      meaning == other.meaning and
      (allophones.subset?(other.allophones) or other.allophones.subset?(allophones))
    end

    # A backslash-delimited list of allphone transcriptions followed by a
    # meaning.
    def to_s
      "#{transcription}: #{meaning}"
    end

    def inspect
      to_s
    end

    # A backslash-delimited list of allphone transcriptions.
    def transcription
      allophones.to_a.map do |allophone|
        allophone.map { |phone| phone.ipa }.join
      end.sort.join("/")
    end
  end


  # A word is a pairing of a sequence of morphemes and phones with a meaning.
  class Word
    # A sequence of Morpheme and Phone objects
    attr_reader :phonetic_component
    # A FeatureValueMatrix representing the meaning
    attr_reader :meaning

    def initialize(phonetic_component, meaning)
      @phonetic_component = phonetic_component
      @meaning = meaning
    end

    # A phone and morpheme transcription followed by the meaning.
    def to_s
      "#{transcription}: #{meaning}"
    end

    def inspect
      to_s
    end

    # Phone and morpheme transcription of the word.
    #
    # Morphemes are set off in square brackets.  Multiple allophones are
    # backslash-delimited.
    def transcription
      @phonetic_component.map do |p|
        case p
        when Phone
          p.ipa
        when Morpheme
          "[#{p.transcription}]"
        else
          raise RuntimeError.new("Invalid phonetic component item #{p}")
        end
      end.join
    end

    # A Word is fully-analyzed if its phonetic component consists entirely of
    # morphemes.
    def fully_analyzed?
      phonetic_component.all? { |p| p.is_a?(Morpheme) }
    end

  end


  # An edit-distance alignment between the phonetic components of two words.
  class Alignment < EditAlign::Alignment
    INFINITY = 1.0/0

    # List of segment boundary offsets
    attr_reader :segment_boundaries

    # Align two Word objects
    #
    # [_word1_] word to align
    # [_word2_] word to align
    def initialize(word1, word2)
      @segment_boundaries = []
      super(word1.phonetic_component.clone, word2.phonetic_component.clone)
    end

    # The string representation of the alignment consists of four or five
    # lines:
    #
    # 1. The source array
    # 2. The destination array
    # 3. An annotation line with S, I, D or nothing for aligned elements
    # 4. An optional emphasis line for emphasized segments
    # 5. The match rate
    #
    # [_emphasis_] segment to emphasize
    def to_s(emphasis = nil)
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
      lines = [s_line, d_line, ops]
      # Find the longest element in all the lines.
      longest = lines.map do |l|
        l.map{|e| e.jlength}.max
      end.max
      # Optionally add a line of carets beneath an emphasized segment.
      if not emphasis.nil?
        emphasis_from, emphasis_to = segment_range(emphasis)
        # emphasis_from = emphasis.zero? ? 0 : segment_boundaries[emphasis-1]
        # emphasis_to = emphasis == segment_boundaries.length ?
        #   s_line.length : segment_boundaries[emphasis]
        emphasis_line = []
        emphasis_line += [""] * (emphasis_from - 0)
        emphasis_line += ["^" * longest] * (emphasis_to - emphasis_from + 1)
        emphasis_line += [""] * (s_line.length - emphasis_to - 1)
        lines << emphasis_line
      end
      # Insert segment boundary markers.
      segment_boundaries.each_with_index do |b, i|
        index = b + i
        lines.each { |l| l.insert(index, "|") }
      end
      # Center each array element over a field of that width.
      lines = lines.map do |list|
        list.map{|c| c.center(longest)}.join
      end
      (lines + [(sprintf "%0.4f", match_rate)]).join("\n")
    end

    # The number of slots in the alignment.
    def length
      edit_operations.length
    end

    # Alignment match rate
    #
    # The match rate is a number from 0 to 1 that measures the similarity of
    # the two aligned words.
    def match_rate
      # TODO Different match rate for morpheme and phone alignments.
      ops = edit_operations
      match = 0
      ops.each { |op| match += 1 if op.nil? }
      match/ops.length.to_f
    end

    def each_morpheme_hypothesis
      # TODO Implement each_morpheme_hypothesis
    end

    # Divide the alignment into segments
    #
    # Segment boundaries are inserted between every pair of alignment slots
    # that have different phonetic edit operations.  Phone substitutions less
    # than or equal to a threshold are treated as matching for the purposes of
    # segmentation.
    #
    # [<em>substitution_threshold</em>] difference beneath which phone
    #                                   subsitutions are treated as matching
    def segment!(substitution_threshold = 0)
      @segment_boundaries = []
      @substitution_threshold = substitution_threshold
      ops = phonetic_operations
      # Insert boundaries at phonetic operation discontinuities.
      1.upto(ops.length-1) do |i|
        @segment_boundaries << i if not ops[i] == ops[i-1]
      end
    end

    # The segments in this alignment.  This returns and Array of Segment
    # objects.
    def segments
      s = []
      0.upto(segment_boundaries.length) do |index|
        s << Segment.new(self, index)
      end
      s
    end

    # Beginning and ending slot indexes of the specified segment.
    #
    # [_index_] index of a segment in this alignment
    def segment_range(index)
      from = index.zero? ? 0 : segment_boundaries[index-1]
      to = index == segment_boundaries.length ? length :
                                                segment_boundaries[index]
      [from, to-1]
    end

    # Phonetic edit operations
    #
    # The list of phonetic edit operations is the same as the list returned by
    # the alignment algorithm except that phone substitutions between phones
    # whose distance falls below a given threshold are treated as aligned
    # slots.
    #
    # The threshold is specified when segment! is called.  If the alignment
    # has not yet been segmented, this function simply returns the edit
    # operations.
    def phonetic_operations
      ops = edit_operations.clone
      return ops if @substitution_threshold.nil?
      word1 = source_alignment
      word2 = dest_alignment
      ops.each_with_index do |op, i|
        if op == :substitute and
           word1[i].kind_of?(Phone) and word2[i].kind_of?(Phone) and
           (word1[i] - word2[i]) <= @substitution_threshold
          ops[i] = nil
        end
      end
      ops
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


  # A segment is a contiguous portion of an alignment.
  class Segment
    # [_alignment_] alignment in which this segment appears
    # [_index_] index of this segment
    def initialize(alignment, index)
      @alignment = alignment
      @index = index
    end

    # The alignment with this segmenent emphasized.
    def to_s
      @alignment.to_s(@index)
    end

    # Is this segment phonetically the same in both words?
    def phonetically_same?
      from, to = @alignment.segment_range(@index)
      @alignment.phonetic_operations[from..to].all? {|op| op.nil?}
    end

    # Is this segment phonetically different in the two words?
    def phonetically_different?
      not phonetically_same?
    end

  end

end
