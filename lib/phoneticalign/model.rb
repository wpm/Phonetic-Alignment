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


end
