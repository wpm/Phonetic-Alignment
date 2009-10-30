require "helper"


class FeatureValueMatrixTestCase < Test::Unit::TestCase
  context "A FeatureValueMatrix" do
    setup do
      @a = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3]
    end

    should "stringify with square brackets in feature order" do
      assert_equal("[f1 = v1, f2 = v2, f3 = v3]", @a.to_s)
    end

    should "be creatable from a hash" do
      b = PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2, :f3 => :v3]
      assert(@a == b, "#{@a} != #{b}")
    end
  end

  context "The FeatureValueMatrix intersection operator" do
    setup do
      @a = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3]
      @b = PhoneticAlign::FeatureValueMatrix[:f2, :v2, :f3, :v3, :f4, :v4]
      @c = PhoneticAlign::FeatureValueMatrix[:f5, :v5, :f6, :v6]
      @empty = PhoneticAlign::FeatureValueMatrix.new
    end

    should "be symmetric" do
      assert_equal(@a & @b, @b & @a)
      assert_equal(@a & @c, @c & @a)
      assert_equal(@b & @c, @c & @b)
    end

    should "return the feature-value pairs the operands have in common" do
      assert_equal(PhoneticAlign::FeatureValueMatrix[:f2, :v2, :f3, :v3], @a & @b)
    end

    should "return an empty matrix for operands with no features in common" do
      assert_equal(@empty, @a & @c)
    end

    should "return an empty matrix for empty operands" do
      assert_equal(@empty, @empty & @empty)
    end

  end

  context "The FeatureValueMatrix addition operator" do
    setup do
      @a = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3]
      @b = PhoneticAlign::FeatureValueMatrix[:f2, :v2, :f3, :v3, :f4, :v4]
      @c = PhoneticAlign::FeatureValueMatrix[:f5, :v5, :f6, :v6]
      @d = PhoneticAlign::FeatureValueMatrix[:f5, :v6]
      @empty = PhoneticAlign::FeatureValueMatrix.new
    end

    should "return the union of the feature-value pairs in the operands" do
      sum = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3, :f4, :v4]
      assert_equal(sum, @a + @b)
      sum = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3, :f5, :v5, :f6, :v6]
      assert_equal(sum, @a + @c)
    end

    should "be symmetric" do
      assert_equal(@a & @b, @b & @a)
      assert_equal(@a & @c, @c & @a)
      assert_equal(@b & @c, @c & @b)
    end

    should "return an empty matrix for empty operands" do
      assert_equal(@empty, @empty & @empty)
    end

    should "raise an ArgumentError if the operands have a value mismatch" do
      assert_raise(ArgumentError) { @c + @d }
      assert_raise(ArgumentError) { @d + @c }
    end
  end

  context "The FeatureValueMatrix difference operator" do
    setup do
      @a = PhoneticAlign::FeatureValueMatrix[:f1, :v1, :f2, :v2, :f3, :v3]
      @b = PhoneticAlign::FeatureValueMatrix[:f2, :v2, :f3, :v3, :f4, :v4]
      @c = PhoneticAlign::FeatureValueMatrix[:f5, :v5, :f6, :v6]
      @empty = PhoneticAlign::FeatureValueMatrix.new
    end

    should "return the feature-value pairs in the first and not the second operand" do
      assert_equal(PhoneticAlign::FeatureValueMatrix[:f1, :v1], @a - @b)
      assert_equal(PhoneticAlign::FeatureValueMatrix[:f4, :v4], @b - @a)
      assert_equal(@a, @a - @c)
    end

    should "be asymmetric" do
      assert_not_equal(@a - @b, @b - @a)
      assert_not_equal(@a - @c, @c - @a)
      assert_not_equal(@b - @c, @c - @b)
    end

    should "return an empty matrix for empty operands" do
      assert_equal(@empty, @empty & @empty)
    end
  end
end


class PhoneTestCase < Test::Unit::TestCase
  context "A Phone" do
    setup do
      @j = PhoneticAlign::Phone.new("dʒ",
            PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2])
      @s = PhoneticAlign::Phone.new("s",
            PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v3])
    end

    should "handle unicode IPA characters" do
      assert_equal("dʒ", @j.ipa)
      assert_equal(2, @j.ipa.jlength)
    end

    should "have a default empty feature matrix" do
      p = PhoneticAlign::Phone.new("p")
      assert_equal("p", p.ipa)
      assert_equal(PhoneticAlign::FeatureValueMatrix.new, p.features)
    end

    should "define a difference operator based on feature similarity" do
      assert_equal(0.5, @j - @s)
      assert_equal(0.5, @s - @j)
    end

    should "stringify on a single line with the IPA character followed by the features" do
      assert_equal("dʒ: [f1 = v1, f2 = v2]", @j.to_s)
    end
  end
end


class Morpheme < Test::Unit::TestCase
  def setup
    @phone_e = PhoneticAlign::Phone.new("e")
    @phone_d = PhoneticAlign::Phone.new("d")
    @phone_s = PhoneticAlign::Phone.new("s")
    @phone_z = PhoneticAlign::Phone.new("z")
    @plural = PhoneticAlign::FeatureValueMatrix[:NUMBER => :plural]
    @past = PhoneticAlign::FeatureValueMatrix[:TENSE => :past]
    @s = PhoneticAlign::Morpheme.new([[@phone_s]], @plural)
    @z = PhoneticAlign::Morpheme.new([[@phone_z]], @plural)
    @sz = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
    @ed = PhoneticAlign::Morpheme.new([[@phone_e, @phone_d]], @past)
  end

  context "A Morpheme" do
    should "Equal another morpheme with the same allophones and meaning" do
      sz1 = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      sz2 = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      assert(sz1 == sz2, "#{sz1} != #{sz2}")
    end

    should "have a transcription that is a backslash-delimited list of allphone transcriptions" do
      assert_equal("s", @s.transcription)
      assert_equal("s/z", @sz.transcription)
      assert_equal("ed", @ed.transcription)
    end

    should "stringify as a backslash-delimited list of allphone transcriptions followed by a meaning" do
      assert_equal("s: [NUMBER = plural]", @s.to_s)
      assert_equal("s/z: [NUMBER = plural]", @sz.to_s)
      assert_equal("ed: [TENSE = past]", @ed.to_s)
    end

    should "Accept either a list or a set of allophones in its constructor" do
      sz_set = PhoneticAlign::Morpheme.new(Set.new([[@phone_s], [@phone_z]]), @plural)
      sz_list = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      assert_instance_of(Set, sz_list.allophones)
      assert(sz_set == sz_list, "#{sz_set} != #{sz_list}")
    end
  end

  context "A pair of Morphemes" do
    should "be compatible if they have the same meanings and one's allophone set subsumes the other's" do
      assert(@s.compatible?(@s))
      assert(@s.compatible?(@sz))
    end

    should "not be compatible if they have the same meaning but non-intersecting allophone sets" do
      assert(!@s.compatible?(@z))
    end

    should "not be compatible if they have different meanings" do
      assert(!@s.compatible?(@ed))
      assert(!@z.compatible?(@ed))
      assert(!@sz.compatible?(@ed))
      assert(!@ed.compatible?(@s))
    end
  end
end


class Word < Test::Unit::TestCase
  context "A Word" do
    setup do
      @c = PhoneticAlign::Phone.new("c")
      @a = PhoneticAlign::Phone.new("a")
      @t = PhoneticAlign::Phone.new("t")
      @s = PhoneticAlign::Phone.new("s")
      @lemma_cat = PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat]
      @number_plural = PhoneticAlign::FeatureValueMatrix[:NUMBER => :plural]
      @cat_morph = PhoneticAlign::Morpheme.new([[@c, @a, @t]], @lemma_cat)
      @s_morph = PhoneticAlign::Morpheme.new([[@s]], @number_plural)
      @cats_meaning = PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat, :NUMBER => :plural]
    end

    should "permit a phonetic component consisting of all phones" do
      all_phones = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert_equal([@c, @a, @t, @s], all_phones.phonetic_component)
      assert_equal(@cats_meaning, all_phones.meaning)
    end

    should "permit a phonetic component consisting of phones and morphemes" do
      phone_and_morphs = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert_equal([@cat_morph, @s], phone_and_morphs.phonetic_component)
      assert_equal(@cats_meaning, phone_and_morphs.meaning)
    end

    should "permit a phonetic component consisting of all morphemes" do
      all_morphs = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert_equal([@cat_morph, @s_morph], all_morphs.phonetic_component)
      assert_equal(@cats_meaning, all_morphs.meaning)
    end

    should "stringify as a bracketed transcription followed by a meaning" do
      w = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert_equal("cats: [LEMMA = cat, NUMBER = plural]", w.to_s)
      w = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert_equal("[cat]s: [LEMMA = cat, NUMBER = plural]", w.to_s)
      w = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert_equal("[cat][s]: [LEMMA = cat, NUMBER = plural]", w.to_s)
      z = PhoneticAlign::Phone.new("z")
      sz_morph = PhoneticAlign::Morpheme.new([[@s], [z]], @number_plural)
      w = PhoneticAlign::Word.new([@cat_morph, sz_morph], @cats_meaning)
      assert_equal("[cat][s/z]: [LEMMA = cat, NUMBER = plural]", w.to_s)
    end

  end
end
