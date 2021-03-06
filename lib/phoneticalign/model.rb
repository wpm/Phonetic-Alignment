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
    def ==(other)
      # Do explicit type checking instead of relying on duck typing because
      # the == operator for Alignment may compare Phones with strings.
      other.kind_of?(Phone) and
      ipa == other.ipa and
      features == other.features
    end

    # Phone defines eql? and hash so that we may use Phone objects as hash
    # keys.
    def eql?(other)
      self == other
    end

    # Phone defines eql? and hash so that we may use Phone objects as hash
    # keys.
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


  # A sequence of phones.
  class PhoneSequence < Array
    # Create a phone sequence
    #
    # [_phones_] Array of Phone objects or a String
    #
    # If _phones_ is a string it is converted into an array of phones with the
    # characters as IPA and no phonetic features.
    def initialize(phones = [])
      if phones.kind_of?(String)
        phones = phones.split("").map { |p| Phone.new(p) }
      end
      super(phones)
    end

    # The IPA transcription of the phone sequence without the features.
    def transcription
      map { |p| p.ipa }.join
    end

  end


  # A set of allomorphs for a morpheme.
  class AllomorphSet < Set
    # Create the allomorph set
    #
    # [_allomorphs_] list of PhoneSequence objects or strings
    #
    # Items in the _allomorphs_ list are converted the PhoneSequence objects
    # if they are not PhoneSequences already.
    def initialize(allomorphs)
      allomorphs = allomorphs.map do |allomorph|
        allomorph.kind_of?(PhoneSequence) ? allomorph :
                                            PhoneSequence.new(allomorph)
      end
      super(allomorphs)
    end

    # Display sorted allomorphs delimited by '/'.
    def to_s
      to_a.map do |allomorph|
        allomorph.transcription
      end.sort.join("/")
    end
    
    # Two allomorph sets are compatible if the allomorphs of one are a subset
    # of the allomorphs of the other.
    def is_compatible?(other)
      subset?(other) or other.subset?(self)
    end

  end


  # A morpheme is a pairing of a set of allomorphs and a meaning.
  class Morpheme
    # An AllomorphSet
    attr_reader :allomorphs
    # A FeatureValueMatrix representing the meaning
    attr_accessor :meaning

    # Create the morpheme from a set of allomorphs and a meaning.
    #
    # [<em>allomorphs</em>] AllomorphSet or list of phone sequences
    # [_meaning_] the meaning
    #
    # An allomorph is a sequence of phones that represents a possible surface
    # instantiation of this morpheme. If strings are given for the
    # <em>allomorphs</em> these are converted into lists of Phone objects
    # without phonetic features.
    #
    # If a hash is given for the meaning, it is converted into a
    # FeatureValueMatrix.
    def initialize(allomorphs, meaning)
      if not allomorphs.is_a?(AllomorphSet)
        allomorphs = AllomorphSet.new(allomorphs)
      end
      @allomorphs = allomorphs
      if meaning.instance_of?(Hash)
        meaning = FeatureValueMatrix.from_hash(meaning)
      end
      @meaning = meaning
    end

    # Morphemes are equal if their allomorphs and meanings are the same.
    def ==(other)
      # Do explicit type checking instead of relying on duck typing because
      # the == operator for Alignment may compare Phones with strings.
      other.kind_of?(Morpheme) and
      allomorphs == other.allomorphs and meaning == other.meaning
    end

    # Morpheme defines eql? and hash so that we may use Morpheme objects as
    # hash keys.
    def eql?(other)
      self == other
    end

    # Morpheme defines eql? and hash so that we may use Morpheme objects as
    # hash keys.
    def hash
      [allomorphs, meaning].hash
    end

    # Two morphemes are compatible if they have the same meaning and the
    # allomorphs of one are a subset of the allomorphs of the other.
    def is_compatible?(other)
      meaning == other.meaning and
      allomorphs.is_compatible?(other.allomorphs)
    end

    def same_meaning_template?(other)
      Set.new(meaning.keys) == Set.new(other.meaning.keys)
    end

    # A backslash-delimited list of allomorph transcriptions followed by a
    # meaning.
    def to_s
      "#{transcription}: #{meaning}"
    end

    def inspect
      to_s
    end

    # A backslash-delimited list of allomorph transcriptions.
    def transcription
      "[#{allomorphs}]"
    end
  end


  # An instance of a morpheme that appears in a particular word.
  #
  # This refines that Morpheme object with a surface form, which is the
  # sequence of phones that appear in this particular instance.
  class SurfaceMorpheme < Morpheme
    attr_reader :surface_form

    # Create the morpheme from a set of allomorphs and a meaning.
    #
    # [_meaning_] the meaning
    # [<em>surface_form</em>] the surface form
    # [<em>allomorphs</em>] AllomorphSet or list of strings or phone sequences
    #
    # If a hash is given for the meaning, it is converted into a
    # FeatureValueMatrix.
    #
    # The surface form is the sequence of phones that represents this
    # morpheme's surface form in a particular context.  If a string is passed
    # in for this argument, it is converted to a PhoneSequence where the
    # phones are the characters of the string and have no features.
    #
    # An allomorph is a sequence of phones that represents a possible surface
    # instantiation of this morpheme. If strings are given for the
    # <em>allomorphs</em> these are converted into lists of Phone objects
    # without phonetic features.
    #
    # The surface form must be included in the set of allomorphs.
    def initialize(meaning, surface_form, allomorphs = nil)
      if not surface_form.kind_of?(PhoneSequence)
        surface_form = PhoneSequence.new(surface_form)
      end
      @surface_form = surface_form
      allomorphs = case allomorphs
      when nil
        AllomorphSet.new([surface_form])
      when AllomorphSet
        allomorphs
      else
        AllomorphSet.new(allomorphs)
      end
      if not allomorphs.include?(surface_form)
        raise ArgumentError.new("#{surface_form} is not one " +
                                "of the allomorphs #{allomorphs.inspect}")
      end
      super(allomorphs, meaning)
    end

    # Surface morphemes are equal if their surface forms, allomorphs and
    # meanings are the same.
    def ==(other)
      super and surface_form == other.surface_form
    end

    # A transcription of the surface form inside square brackets.
    def transcription
      "[#{surface_form.transcription}]"
    end

    # The number of phones in the surface form.
    def length
      surface_form.length
    end

  end


  # A word is a pairing of a sequence of surfaces morphemes and phones with a
  # meaning.
  class Word
    # A sequence of SurfaceMorpheme and Phone objects
    attr_accessor :phonetic_component
    # A FeatureValueMatrix representing the meaning
    attr_reader :meaning

    # Create a word
    #
    # [<em>phonetic_component</em>] a sequence of SurfaceMorpheme and Phone
    #                               objects or a string
    # [_meaning_] a FeatureValueMatrix representing the word's meaning
    #
    # If a string is given for <em>phonetic_component</em> it is converted
    # into an array of phones with the characters as IPA and no phonetic
    # features.
    def initialize(phonetic_component, meaning)
      if phonetic_component.kind_of?(String)
        phonetic_component = phonetic_component.split("").collect do |s|
          Phone.new(s)
        end
      end
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

    # Two words are the same if they have the same phonetic component and
    # meaning.
    def ==(other)
      phonetic_component.map { |p| p.class } == other.phonetic_component.map { |p| p.class } and
      phonetic_component == other.phonetic_component and
      meaning == other.meaning
    end

    # Word defines eql? and hash so that we may use Word objects as hash keys.
    def eql?(other)
      self == other
    end
    
    # Word defines eql? and hash so that we may use Word objects as hash keys.
    def hash
      [phonetic_component, meaning].hash
    end

    # Phone and morpheme transcription of the word.
    #
    # Morphemes are set off in square brackets.  Multiple allomorphs are
    # backslash-delimited.
    def transcription
      @phonetic_component.map { |p| p.transcription }.join
    end

    # The sum of all the meanings of the morphemes in this word.
    def analyzed_meaning
      meaning = FeatureValueMatrix.new
      phonetic_component.each do |item|
        meaning += item.meaning if item.kind_of?(Morpheme)
      end
      meaning
    end

    # The number of phones in the phonetic component that are not in
    # morphemes.
    def unanlayzed_phone_count
      n = 0
      phonetic_component.each do |item|
        n += 1 if item.kind_of?(Phone)
      end
      n
    end

    # A Word is fully-analyzed if its phonetic component consists entirely of
    # morphemes.
    def fully_analyzed?
      phonetic_component.all? { |p| p.is_a?(Morpheme) }
    end

  end


  # An edit-distance alignment between the phonetic components of two words.
  class Alignment
    attr_reader :source_word, :dest_word
    attr_reader :source_alignment, :dest_alignment, :edit_operations

    # Align two Word objects
    #
    # [_source_] word to align
    # [_dest_] word to align
    def initialize(source, dest)
      @source_word = source
      @dest_word = dest
      # This function creates an AlignmentResult object, copies out the
      # necessary data structures, and then discards the object.  We do this
      # instead of having Alignment inherit from EditAlign::Alignment because
      # the latter contains Hash objects with default procedures, making it
      # impossible to deep copy with the Marshal.load(Marshal.dump(object))
      # idiom.  Deep copy support is needed for the MorphologicalAnalysis
      # object, which stores a table of Alignments.
      alignment = AlignmentResult.new(source, dest)
      @source_alignment = alignment.source_alignment
      @dest_alignment = alignment.dest_alignment
      @edit_operations = alignment.edit_operations
      # TODO Push morpheme insertion/deletions outside unaligned phone region.
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
      # Create the source and destination lines.  Replace nils with '-' and
      # other objects with their transcriptions.
      s_line, d_line = [source_alignment, dest_alignment].map do |alignment|
        alignment.map do |s|
          s.nil? ? '-' : s.transcription
        end
      end
      # Create short mnemonics for the edit operations.
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

    # Terse stringification with source and dest word transcriptions separated
    # by a backslash.
    def inspect
      "#{source_word.transcription}/#{dest_word.transcription}"
    end

    # Two alignments are equal if they have the same source alignment, dest
    # alignment, and edit operations.
    def ==(other)
      source_alignment == other.source_alignment and
      dest_alignment == other.dest_alignment and
      edit_operations == other.edit_operations
    end

    # Alignment defines eql? and hash so that we may use Alignment objects as
    # hash keys.
    def eql?(other)
      self == other
    end

    # Alignment defines eql? and hash so that we may use Alignment objects as
    # hash keys.
    def hash
      [source_alignment, dest_alignment, edit_operations].hash
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
    # This is the fraction of aligned slots over total slots.  Each phone
    # counts as one slot and is aligned if its edit operation is nil. 
    # Morphemes count for as many slots as their longest phoneme and are
    # always aligned.
    #
    # [_ops_] list of edit operations
    def match_rate(ops = nil)
      ops = edit_operations if ops.nil?
      match = 0
      ops.each_with_index do |op, i|
        if source_alignment[i].kind_of?(SurfaceMorpheme) and
           dest_alignment[i].kind_of?(SurfaceMorpheme)
          # Aligned surface morpheme count as a match.
          match += 1
        else
          # Aligned phones count as a match if they are the same.
          match += op.nil? ? 1 : 0
        end
      end
      match/ops.length.to_f
    end

    # Divide the alignment into segments
    #
    # This returns a Segmentation for this alignment.
    #
    # [<em>substitution_threshold</em>] difference beneath which phone
    #                                   subsitutions are treated as matching
    def segmentation(substitution_threshold = 0)
      # TODO This function is dumb.  Caller should call Segmentation.new directly.
      Segmentation.new(self, substitution_threshold)
    end

  end

  # The result of performing an alignment between two Word objects.
  class AlignmentResult < EditAlign::Alignment
    @@INFINITY = 1.0/0

    # Align two Word objects
    #
    # [_source_] word to align
    # [_dest_] word to align
    def initialize(source, dest)
      super(source.phonetic_component.clone, dest.phonetic_component.clone)
    end
    
    # The substitution cost function used to perform alignments.
    #
    # The cost of substituting one segment for another in an alignment is
    # equal to the distance between them.
    #
    # [_item1_] a Phone, SurfaceMorpheme, or nil
    # [_item2_] a Phone, SurfaceMorpheme, or nil
    #
    # This function is called by the parent class.
    def substitute(item1, item2)
      if item1.class == item2.class and item1 == item2
        0
      elsif item1.nil? or item2.nil?
        # Insertions and deletions have a cost of 1.
        1
      elsif item1.is_a?(SurfaceMorpheme) and item2.is_a?(SurfaceMorpheme)
        # Align morphemes with same meaning template.
        item1.same_meaning_template?(item2) ? 0 : @@INFINITY
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
      @alignment = alignment
      @substitution_threshold = substitution_threshold
      @segment_boundaries = []
      ops = phonetic_operations
      # Insert boundaries at phonetic operation discontinuities and after
      # morphemes.
      1.upto(ops.length-1) do |i|
        if ops[i] != ops[i-1] or
          source_alignment[i-1].kind_of?(Morpheme) or
          dest_alignment[i-1].kind_of?(Morpheme)
          segment_boundaries << i
          # TODO are phonetic Subs followed by Ins or Dels really discontinuous?
        end
      end
    end

    def to_s
      alignment.to_s(segment_boundaries)
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
      # TODO Ignore if all morphemes align with all phones?
      different_segments = find_all {|s| s.phonetically_different?}
      same_segments = find_all {|s| s.phonetically_same?}
      # If only one of the alignment segments is phonetically different,
      # hypothesize the difference of the word meanings for the corresponding
      # word segments.
      if different_segments.length == 1
        different_segment = different_segments.first
        if different_segment.is_phones?(:source)
          morph = SurfaceMorpheme.new(source_word.meaning - dest_word.meaning,
                                      different_segment.phonetic_component(:source))
          yield MorphemeHypothesis.new(different_segment, :source, morph)
        end
        if different_segment.is_phones?(:dest)
          morph = SurfaceMorpheme.new(dest_word.meaning - source_word.meaning,
                                      different_segment.phonetic_component(:dest))
          yield MorphemeHypothesis.new(different_segment, :dest, morph)
        end
      end
      # If only one of the alignment segments is the same, hypothesize the
      # intersection of the word meanings for both of the corresponding word
      # segments.
      if same_segments.length == 1
        segment = same_segments.first
        if segment.is_phones?(:source) # If source is phones so is dest.
          shared_meaning = source_word.meaning & dest_word.meaning
          same_segment = same_segments.first
          # The aligned phonetic components become allomorphs in the new
          # morpheme.
          source_allomorph = same_segment.phonetic_component(:source)
          dest_allomorph = same_segment.phonetic_component(:dest)
          source_morph = SurfaceMorpheme.new(shared_meaning, source_allomorph,
                                             [source_allomorph, dest_allomorph])
          yield MorphemeHypothesis.new(same_segment, :source, source_morph)
          dest_morph = SurfaceMorpheme.new(shared_meaning, dest_allomorph,
                                          [source_allomorph, dest_allomorph])
          yield MorphemeHypothesis.new(same_segment, :dest, dest_morph)
        end
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
          if segment.is_phones?(word)
            phone_sequences << segment
          elsif meaning
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
          if not meaning.empty?
            phone_segment = phone_sequences.first
            morph = SurfaceMorpheme.new(meaning,
                                  phone_segment.phonetic_component(word))
            yield MorphemeHypothesis.new(phone_sequences.first, word, morph)
          end
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
      ops = alignment.edit_operations.clone
      return ops if @substitution_threshold.nil?
      source = alignment.source_alignment
      dest = alignment.dest_alignment
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
      alignment.send(method, *args)
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

    # Is the phonetic component of the specified word comprised entirely of
    # phones and not morphemes or nil?
    #
    # [_word_] :source or :dest
    def is_phones?(word)
      phonetic_component(word).all? {|item| item.kind_of?(Phone)}
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
    
    # Two morpheme hypotheses are equal if they specify the same morpheme for
    # the same phonetic component range in the same word.
    def ==(other)
      original_word == other.original_word and
      original_word_offsets == other.original_word_offsets and
      morpheme == other.morpheme
    end

    # MorphemeHypothesis defines eql? and hash so that we may use
    # MorphemeHypothesis objects as hash keys.
    def eql?(other)
      self == other
    end
    
    # MorphemeHypothesis defines eql? and hash so that we may use
    # MorphemeHypothesis objects as hash keys.
    def hash
      [original_word, original_word_offsets, morpheme].hash
    end

    # The offsets of this segment in the original word.
    def original_word_offsets
      [original_word_offset(segment.from), original_word_offset(segment.to)]
    end
    
    # Offset of the segment in the original word.
    #
    # [wa]: [DISTANCE = obviate, NUMBER = singular]
    #    a      t      i      |      -      |      m      |      w      a
    #    -      -      -      |   [amisk]   |      -      |      w      a    <==
    #    D      D      D      |      I      |      D      |
    #
    # The slot index of the "w" in the alignment above is 5.  The original
    # word offset of this slot is 4 in the source word and 1 in the
    # destination word.
    def original_word_offset(slot_index)
      word_alignment = case word
      when :source
        segment.source_alignment
      when :dest
        segment.dest_alignment
      else
        raise RuntimeError.new("Invalid word value #{word}")
      end
      word_alignment[0..slot_index].find_all do |p|
        not p.nil?
      end.length - 1
    end

    # Return the original word in the alignment.
    def original_word
      case word
      when :source
        segment.source_word
      when :dest
        segment.dest_word
      else
        raise RuntimeError.new("Invalid word value #{word}")
      end
    end

    # The match rate of this hypothesis' alignment.
    def match_rate
      segment.match_rate
    end
    
    # The alignment from which this hypothesis was generated.
    def alignment
      segment.alignment
    end
    
    # Send unhandled calls down to the morpheme.
    def method_missing(method, *args)
      morpheme.send(method, *args)
    end

  end


end
