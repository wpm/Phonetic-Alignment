require "editalign"
require "set"


module PhoneticAlign

  # A pairing of features and values.
  #
  # This is a hash that defines intersection and difference operators.
  class FeatureValueMatrix < Hash

    # Create a feature matrix from a hash table.
    #
    # [_h_] hash table
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

    # Create a phone
    #
    # [_ipa_] IPA transcription of this phone
    # [_features_] optional FeatureValueMatrix describing the phonetic
    #              features
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

    # Defined eql? because this class defines its own hash function.
    def eql?(other)
      self == other
    end

    # Phones must define their own hash function in order for indentical sets
    # of allophones to count as the same hash key.
    def hash
      [ipa, features, self.class].hash
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
    # An AllophoneSet
    attr_reader :allophones
    # A FeatureValueMatrix representing the meaning
    attr_accessor :meaning

    # Create the morpheme from a sequence of allophones and a meaning.
    #
    # An allophone is a sequence of phones.
    #
    # [_allophones_] sequence of allophones
    # [_meaning_] the meaning
    def initialize(allophones, meaning)
      if not allophones.is_a?(AllophoneSet)
        allophones = AllophoneSet.new(allophones)
      end
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
      allophones.is_compatible?(other.allophones)
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
      allophones.to_s
    end
  end


  class AllophoneSet < Set
    # [_allophones_] list of allophones
    def initialize(allophones)
      super
    end
    
    # Display sorted allophones delimited by '/'.
    def to_s
      to_a.map do |allophone|
        allophone.map { |phone| phone.ipa }.join
      end.sort.join("/")
    end
    
    # Two allphone sets are compatible if the allophones of one are a subset
    # of the allophones of the other.
    def is_compatible?(other)
      subset?(other) or other.subset?(self)
    end
    
  end


  # A word is a pairing of a sequence of morphemes and phones with a meaning.
  class Word
    # A sequence of Morpheme and Phone objects
    attr_reader :phonetic_component
    # A FeatureValueMatrix representing the meaning
    attr_reader :meaning

    # Create a word
    #
    # [<em>phonetic_component</em>] a sequence of Morpheme and Phone objects
    # [_meaning_] a FeatureValueMatrix representing the word's meaning
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
          p.transcription
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
    @@INFINITY = 1.0/0

    attr_reader :source_word, :dest_word

    # Align two Word objects
    #
    # [_source_] word to align
    # [_dest_] word to align
    def initialize(source, dest)
      @source_word = source
      @dest_word = dest
      super(source.phonetic_component.clone, dest.phonetic_component.clone)
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
    # [<em>segment_boundaries</em>] offsets at which to insert vertical
    #                               boundary markers
    # [_emphasis_] segment to emphasize [from, to]
    def to_s(segment_boundaries = [], emphasis = nil)
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
        emphasis_from, emphasis_to = emphasis
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
    #
    # [_ops_] list of edit operations
    def match_rate(ops = nil)
      # TODO Different match rate for morpheme and phone alignments.
      ops = edit_operations if ops.nil?
      match = 0
      ops.each { |op| match += 1 if op.nil? }
      match/ops.length.to_f
    end

    # Divide the alignment into segments
    #
    # This returns a Segmentation for this alignment.
    #
    # [<em>substitution_threshold</em>] difference beneath which phone
    #                                   subsitutions are treated as matching
    def segmentation(substitution_threshold = 0)
      Segmentation.new(self, substitution_threshold)
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
        item1.is_compatible?(item2) ? 0 : @@INFINITY
      elsif item1.is_a?(Phone) and item2.is_a?(Phone)
        # The substitution cost of non-equal phones is a function of their
        # phonetic distance.
        # TODO Scale by substitution penalty.
        item1 - item2
      else
        # Phones and morphemes never align.
        @@INFINITY
      end
    end

  end


  # A division of an Alignment into contiguous segments.
  class Segmentation
    include Enumerable

    attr_reader :alignment, :segment_boundaries

    # Divide an alignment into segments
    #
    # Segment boundaries are inserted between every pair of alignment slots
    # that have different phonetic edit operations.  Phone substitutions less
    # than or equal to a threshold are treated as matching for the purposes of
    # segmentation.
    #
    # [<em>substitution_threshold</em>] difference beneath which phone
    #                                   subsitutions are treated as matching
    def initialize(alignment, substitution_threshold)
      # TODO Insert boundaries around morphemes.
      @alignment = alignment
      @substitution_threshold = substitution_threshold
      @segment_boundaries = []
      ops = phonetic_operations
      # Insert boundaries at phonetic operation discontinuities.
      1.upto(ops.length-1) do |i|
        @segment_boundaries << i if not ops[i] == ops[i-1]
      end
    end

    def to_s
      @alignment.to_s(segment_boundaries)
    end

    # The number of segments
    def length
      segment_boundaries.length + 1
    end

    # Two segmentations are equal if they come from the same alignment and
    # have the same segment boundaries.
    def ==(other)
      alignment == other.alignment and
      segment_boundaries == other.segment_boundaries
    end

    # Return the specified segment.
    #
    # [_index_] segment index
    def [](index)
      from = index.zero? ? 0 : segment_boundaries[index-1]
      to = index == segment_boundaries.length ? alignment.length-1 :
                                                segment_boundaries[index]-1
      Segment.new(self, from, to)
    end

    # The match rate of the alignment where phone substitutions with a cost
    # beneath the threshold count as aligned.
    def match_rate
      alignment.match_rate(phonetic_operations)
    end

    # Enumerate segments in order.
    def each
      boundaries = [0] + segment_boundaries + [alignment.length]
      boundaries.each_cons(2) do |from, to|
        yield Segment.new(self, from, to-1)
      end
    end

    # Enumerate morpheme hypotheses
    def each_morpheme_hypothesis
      different_segments = find_all {|s| s.phonetically_different?}
      same_segments = find_all {|s| s.phonetically_same?}
      # If only one of the alignment segments is phonetically different,
      # hypothesize the difference of the word meanings for the corresponding
      # word segments.
      if different_segments.length == 1
        different_segment = different_segments.first
        if not different_segment.phonetically_empty?(:source)
          morph = Morpheme.new([different_segment.phonetic_component(:source)],
                               source_word.meaning - dest_word.meaning)
          yield MorphemeHypothesis.new(different_segment, :source, morph)
        end
        if not different_segment.phonetically_empty?(:dest)
          morph = Morpheme.new([different_segment.phonetic_component(:dest)],
                               dest_word.meaning - source_word.meaning)
          yield MorphemeHypothesis.new(different_segment, :dest, morph)
        end
      end
      # If only one of the alignment segments is the same, hypothesize the
      # intersection of the word meanings for both of the corresponding word
      # segments.
      if same_segments.length == 1
        segment = same_segments.first
        shared_meaning = source_word.meaning & dest_word.meaning
        same_segment = same_segments.first
        # The aligned phonetic components become allomorphs in the new
        # morpheme.
        source_allophone = same_segment.phonetic_component(:source)
        dest_allophone = same_segment.phonetic_component(:dest)
        morph = Morpheme.new([source_allophone, dest_allophone],
                             shared_meaning)
        yield MorphemeHypothesis.new(same_segment, :source, morph)
        yield MorphemeHypothesis.new(same_segment, :dest, morph)
      end
      # If a given word has only one phonetic segment, hypothesize that its
      # meaning is the word meaning minus the meaning of all other morphemes
      # in the word.
      [:source, :dest].each do |word|
        # Divide the phonetic component into phone sequences and meanings.
        phone_sequences = []
        meanings = []
        each do |segment|
          meaning = segment.meaning(word)
          if meaning.nil?
            phone_sequences << segment
          else
            meanings << meaning
          end
        end
        # If we have a single phone sequence, hypothesize a meaning for it.
        if phone_sequences.length == 1
          morpheme_meaning = 
          meanings.inject(FeatureValueMatrix.new) do |memo, meaning|
            memo += meaning
          end
          word_meaning = word == :source ? source_word.meaning : 
                                           dest_word.meaning
          meaning = word_meaning - morpheme_meaning
          phone_segment = phone_sequences.first
          morph = Morpheme.new([phone_segment.phonetic_component(word)], meaning)
          yield MorphemeHypothesis.new(phone_sequences.first, word, morph)
        end
      end
    end

    # Phonetic edit operations
    #
    # The list of phonetic edit operations is the same as the list returned by
    # the alignment algorithm except that phone substitutions between phones
    # whose distance falls below a given threshold are treated as aligned
    # slots.
    def phonetic_operations
      ops = @alignment.edit_operations.clone
      return ops if @substitution_threshold.nil?
      source = @alignment.source_alignment
      dest = @alignment.dest_alignment
      ops.each_with_index do |op, i|
        if op == :substitute and
           source[i].kind_of?(Phone) and dest[i].kind_of?(Phone) and
           (source[i] - dest[i]) <= @substitution_threshold
          ops[i] = nil
        end
      end
      ops
    end

    # Send unhandled calls down to the alignment.
    def method_missing(method, *args)
      @alignment.send(method, *args)
    end

  end


  # A segment is a contiguous portion of an alignment.
  class Segment
    attr_reader :segmentation, :from, :to

    # Creat a segment
    #
    # [_segmentation_] segmentation in which this segment appears
    # [_from_] the offset at which to begin the segment
    # [_to_] the offset at which to end the segment
    def initialize(segmentation, from, to)
      @segmentation = segmentation
      @from = from
      @to = to
    end

    # The alignment with this segmenent emphasized.
    def to_s
      segmentation.alignment.to_s(segmentation.segment_boundaries,
                                  [from, to])
    end

    # Segments are equal if they come from the same segmentation and have the
    # same offsets.
    def ==(other)
      segmentation == other.segmentation and
      from == other.from and to == other.to
    end

    # Is this segment phonetically the same in both words?
    def phonetically_same?
      segmentation.phonetic_operations[from..to].all? {|op| op.nil?}
    end

    # Is this segment phonetically different in the two words?
    def phonetically_different?
      not phonetically_same?
    end

    # Is this segment phonetically empty in the specified word?
    #
    # [_word_] :source or :dest
    def phonetically_empty?(word)
      phonetic_component(word).all? {|item| item.nil?}
    end

    # The meaning of the aligned word portion in this segment.
    #
    # If the segment consists entirely of morphemes, the meaning is the sum of
    # their meanings.  Otherwise the function returns nil.
    #
    # [_word_] :source or :dest
    def meaning(word)
      p = phonetic_component(word)
      return nil if not p.all? {|item| item.kind_of?(Morpheme)}
      p.inject(FeatureValueMatrix.new) do |meaning, item|
        meaning += item.meaning
      end
    end
    
    # The phonetic component of the specified word in this segment.
    #
    # [_word_] :source or :dest
    def phonetic_component(word)
      word = word == :source ? source_alignment : dest_alignment
      word[from..to]
    end

    # Send unhandled calls down to the segmentation.
    def method_missing(method, *args)
      segmentation.send(method, *args)
    end

  end


  # A pairing of a morpheme with a word segment in an alignment.
  class MorphemeHypothesis
    attr_accessor :segment, :word, :morpheme

    # Create a morpheme hypothesis
    #
    # [_segment_] Segment from which the hypothesis is taken
    # [_word_] word from which this is taken: :source or :dest
    # [_morpheme_] Morpheme hypothesized for this word and segment
    def initialize(segment, word, morpheme)
      @segment = segment
      @word = word
      @morpheme = morpheme
    end
    
    # The alignment with the segment emphasized and an arrow pointing at the
    # word.
    def to_s
      segment_lines = @segment.to_s.split("\n")
      segment_lines[@word == :source ? 0 : 1] += " <=="
      segment_s = segment_lines.join("\n")
      "#{@morpheme}\n#{segment_s}"
    end
    
    def ==(other)
      segment = other.segment and word == other.word and
      morpheme == other.morpheme
    end
    
    # The match rate of this hypothesis' alignment.
    def match_rate
      segment.match_rate
    end
    
    # Send unhandled calls down to the morpheme.
    def method_missing(method, *args)
      morpheme.send(method, *args)
    end

  end


end
