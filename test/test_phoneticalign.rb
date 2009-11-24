require "helper"


# Phone and word tables for various inflections of "jump" and "see".
def jumps_sees
  phones =<<-EOTEXT
FORM, VOWEL, NASAL, VOICED
dʒ,-,-,+
m,-,+,-
ŋ,-,+,+
p,-,-,-
s,-,-,-
z,-,-,+
i,+,-,+
ʌ,+,-,+
EOTEXT
  words =<<-EOTEXT
FORM, LEMMA, PERNUM, ASPECT
dʒʌmp,jump, non-3sg, perfect
dʒʌmps,jump, 3sg, perfect
dʒʌmpiŋ,jump,, imperfect
si,see, non-3sg, perfect
siz,see, 3sg, perfect
siiŋ,see,, imperfect
EOTEXT
  [phones, words]
end


# The words "happy", "unhappy", and "unhappiness" comprised of various
# combinations of phones and morphemes.
def happy_unhappy_unhappiness
  # The distance between 'i' and 'y' is 0.5.  The distance between and two
  # other non-equal phone pairs is 1.  This ensures that 'i' and 'y' will tend
  # align with each other.
  happy_unhappy_phones =<<-EOTEXT
  FORM, LETTER, CLASS
  i, i, iy
  y, y, iy
  a, a, a
  e, e, e
  h, h, h
  n, n, n
  p, p, p
  s, s, s
  u, u, u
  EOTEXT
  phone_table = PhoneticAlign::PhoneTable.new(happy_unhappy_phones)
  # Phonetic sequences
  # Meanings
  un_meaning = PhoneticAlign::FeatureValueMatrix[:POL => :neg]
  happy_meaning = PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy]
  ness_meaning = PhoneticAlign::FeatureValueMatrix[:POS => :noun]
  # Morphemes
  un_morph = PhoneticAlign::Morpheme.new([phone_table.phone_sequence("un")], un_meaning)
  happy_morph = PhoneticAlign::Morpheme.new([phone_table.phone_sequence("happy")], happy_meaning)
  happy_happi_morph = PhoneticAlign::Morpheme.new([phone_table.phone_sequence("happy"),
                                                   phone_table.phone_sequence("happi")], happy_meaning)
  ness_morph = PhoneticAlign::Morpheme.new([phone_table.phone_sequence("ness")], ness_meaning)
  # Words consisting of all phones.
  happy_p = PhoneticAlign::Word.new(phone_table.phone_sequence("happy"), happy_meaning)
  unhappy_p = PhoneticAlign::Word.new(phone_table.phone_sequence("unhappy"), un_meaning + happy_meaning)
  unhappiness_p = PhoneticAlign::Word.new(phone_table.phone_sequence("unhappiness"), un_meaning + happy_meaning + ness_meaning)
  # Words consisting of phones and morphemes.
  unhappy_pm = PhoneticAlign::Word.new([un_morph] + phone_table.phone_sequence("happy"), un_meaning + happy_meaning)
  # Words consisting of all morphemes
  happy_m = PhoneticAlign::Word.new([happy_morph], happy_meaning)
  unhappy_m = PhoneticAlign::Word.new([un_morph, happy_morph], un_meaning + happy_meaning)
  happy_happi_ness_m = PhoneticAlign::Word.new([happy_happi_morph, ness_morph], happy_meaning)
  unhappy_happi_ness_m = PhoneticAlign::Word.new([un_morph, happy_happi_morph, ness_morph], un_meaning + happy_meaning + ness_meaning)
  return Struct.new(:phone_table,
                    :happy_p, :unhappy_p, :unhappiness_p,
                    :unhappy_pm,
                    :happy_m, :unhappy_m, :happy_happi_ness_m, :unhappy_happi_ness_m,
                    :un_meaning, :happy_meaning, :ness_meaning).new(
                    phone_table,
                    happy_p, unhappy_p, unhappiness_p,
                    unhappy_pm,
                    happy_m, unhappy_m, happy_happi_ness_m, unhappy_happi_ness_m,
                    un_meaning, happy_meaning, ness_meaning)
end


class ArrayTestCase < Test::Unit::TestCase
  context "An array" do

    should "support enumeration over symmetric pairs of items" do
      pairs = []
      [1, 2, 3, 4].each_symmetric_pair {|p| pairs << p}
      assert_equal([[2, 1], [3, 1], [3, 2], [4, 1], [4, 2], [4, 3]], pairs.sort)
      # Empty list.
      pairs = []
      [].each_symmetric_pair {|p| pairs << p}
      assert_equal([], pairs)
    end

    should "support enumeration over subsets" do
      powerset = []
      [1,2,3].each_subset {|s| powerset << s}
      assert_equal([[], [1], [1, 2], [1, 2, 3], [1, 3], [2], [2, 3], [3]], powerset.sort)
      # Empty list.
      powerset = []
      [].each_subset {|s| powerset << s}
      assert_equal([[]], powerset)
    end

    should "return a powerset with subsets sorted by length" do
      expected = [[1, 2, 3], [1, 2], [1, 3], [2, 3], [1], [2], [3], []]
      assert_equal(expected, [1,2,3].powerset_by_length)
    end

  end
end


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

    should "equal another phone with the same IPA and features" do
      features = PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2]
      p1 = PhoneticAlign::Phone.new("p", features)
      p2 = PhoneticAlign::Phone.new("p", features)
      assert(p1 == p2, "#{p1} != #{p2}")
    end

    should "not equal another phone with different IPA" do
      p1 = PhoneticAlign::Phone.new("x", PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2])
      p2 = PhoneticAlign::Phone.new("y", PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2])
      assert_not_equal(p1, p2)
    end

    should "not equal another phone with different features" do
      p1 = PhoneticAlign::Phone.new("p", PhoneticAlign::FeatureValueMatrix[:f1 => :v1])
      p2 = PhoneticAlign::Phone.new("p", PhoneticAlign::FeatureValueMatrix[:f2 => :v2])
      assert_not_equal(p1, p2)
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

    should "make the difference operator an IPA indicator function if there are no features" do
      a1 = PhoneticAlign::Phone.new("a")
      a2 = PhoneticAlign::Phone.new("a")
      b = PhoneticAlign::Phone.new("b")
      assert_equal(0, a1 - a2)
      assert_equal(1, b - a1)
      assert_equal(1, a1 - b)
    end

    should "stringify on a single line with the IPA character followed by the features" do
      assert_equal("dʒ [f1 = v1, f2 = v2]", @j.to_s)
    end

    should "stringify with an optional IPA field width" do
      assert_equal("dʒ   [f1 = v1, f2 = v2]", @j.to_s(5))
    end
  end
  
  context "A cloned Phone sequence" do
    setup do
      a = PhoneticAlign::Phone.new(:a)
      b = PhoneticAlign::Phone.new(:b)
      @seq = [a,b]
      @seq_clone = @seq.clone
    end
    
    should "should equal the original" do
      assert_equal(@seq, @seq_clone)
      assert(@seq.eql? @seq_clone)
    end
    
    should "hash with the original" do
      assert_equal(@seq.hash, @seq_clone.hash)
      h = {@seq => :value}
      assert_equal(h[@seq], :value)
      assert_equal(h[@seq_clone], :value)
    end
    
    should "hash in sets with the original" do
      h = {Set.new([@seq]) => :value}
      assert_equal(h[Set.new([@seq])], :value)
      assert_equal(h[Set.new([@seq_clone])], :value)
    end
  end
  
end


class MorphemeTestCase < Test::Unit::TestCase
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
    should "equal another morpheme with the same allophones and meaning" do
      sz1 = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      sz2 = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      assert(sz1 == sz2, "#{sz1} != #{sz2}")
    end

    should "initialize given strings for phone sequences" do
      happy_happi1 = PhoneticAlign::Morpheme.new(["happy", "happi"],
                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      happy_happi2 = PhoneticAlign::Morpheme.new(["happi", "happy"],
                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(happy_happi1, happy_happi2)
      happy = "happy".split("").map { |s| PhoneticAlign::Phone.new(s) }
      happi = "happi".split("").map { |s| PhoneticAlign::Phone.new(s) }
      assert_equal(happy_happi1.allophones, PhoneticAlign::AllophoneSet.new([happy, happi]))
      assert_equal(happy_happi2.allophones, PhoneticAlign::AllophoneSet.new([happy, happi]))
    end

    should "have a length equal to the number of phones in its longest allophone" do
      assert_equal(1, @s.length)
      assert_equal(1, @z.length)
      assert_equal(1, @sz.length)
      assert_equal(2, @ed.length)
    end

    should "have a transcription that is a backslash-delimited list of allphone transcriptions" do
      assert_equal("[s]", @s.transcription)
      assert_equal("[s/z]", @sz.transcription)
      assert_equal("[ed]", @ed.transcription)
    end

    should "stringify as a backslash-delimited list of allphone transcriptions followed by a meaning" do
      assert_equal("[s]: [NUMBER = plural]", @s.to_s)
      assert_equal("[s/z]: [NUMBER = plural]", @sz.to_s)
      assert_equal("[ed]: [TENSE = past]", @ed.to_s)
    end

    should "accept a list of allophones in its constructor" do
      sz_list = PhoneticAlign::Morpheme.new([[@phone_s], [@phone_z]], @plural)
      assert_instance_of(PhoneticAlign::AllophoneSet, sz_list.allophones)
    end
    
    should "have only a single allophone when initialized with a list of identical allophones" do
      e = PhoneticAlign::Phone.new("e", PhoneticAlign::FeatureValueMatrix[:FORM => :e])
      d = PhoneticAlign::Phone.new("d", PhoneticAlign::FeatureValueMatrix[:FORM => :d])
      m = PhoneticAlign::Morpheme.new([[e,d], [e,d]], @past)
      assert_equal(m.allophones, Set.new([[e,d]]))
    end

  end

  context "A pair of Morphemes" do
    should "be compatible if they have the same meanings and one's allophone set subsumes the other's" do
      assert(@s.is_compatible?(@s))
      assert(@s.is_compatible?(@sz))
    end

    should "not be compatible if they have the same meaning but non-intersecting allophone sets" do
      assert(!@s.is_compatible?(@z))
    end

    should "not be compatible if they have different meanings" do
      assert(!@s.is_compatible?(@ed))
      assert(!@z.is_compatible?(@ed))
      assert(!@sz.is_compatible?(@ed))
      assert(!@ed.is_compatible?(@s))
    end
  end
end


class AllophoneSetTestCase < Test::Unit::TestCase
  context "Allophone sets" do
    setup do
      phone_table = happy_unhappy_unhappiness.phone_table
      @happy = phone_table.phone_sequence("happy")
      @happi = phone_table.phone_sequence("happi")
      @ness = phone_table.phone_sequence("ness")
    end
    
    should "be created from lists of phoneme sequences" do
      s = PhoneticAlign::AllophoneSet.new([@happy, @happi])
      assert_equal(Set.new([@happy, @happi]), s)
    end
    
    should "be compatible iff one is a subset of another" do
      happy = PhoneticAlign::AllophoneSet.new([@happy])
      happy_happi = PhoneticAlign::AllophoneSet.new([@happy, @happi])
      ness = PhoneticAlign::AllophoneSet.new([@ness])
      assert(happy.is_compatible?(happy_happi))
      assert(happy_happi.is_compatible?(happy))
      assert((not happy.is_compatible?(ness)))
      assert((not ness.is_compatible?(happy)))
      assert((not happy_happi.is_compatible?(ness)))
      assert((not ness.is_compatible?(happy_happi)))
    end
    
    should "be able to serve as hash keys" do
      happy1 = PhoneticAlign::AllophoneSet.new([@happy])
      happy2 = PhoneticAlign::AllophoneSet.new([@happy])
      ness = PhoneticAlign::AllophoneSet.new([@ness])
      h = {happy1 => :value}
      assert_equal(h[happy2], :value)
      assert_nil(h[ness])
    end
    
    should "stringify with allophones sorted and delimited by /" do
      happy = PhoneticAlign::AllophoneSet.new([@happy])
      assert_equal("happy", happy.to_s)
      happy_happi = PhoneticAlign::AllophoneSet.new([@happy, @happi])
      assert_equal("happi/happy", happy_happi.to_s)
    end
    
  end
end


class WordTestCase < Test::Unit::TestCase
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
      @dogs = PhoneticAlign::Word.new("dogs",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                        :NUMBER => :plural])
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

    should "initialize with a string" do
      string_init = PhoneticAlign::Word.new("cats", @cats_meaning)
      assert_equal([@c, @a, @t, @s], string_init.phonetic_component)
      assert_equal(@cats_meaning, string_init.meaning)
    end

    should "equal another word if the phonetic component and meaning are the same" do
      cats1 = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      cats2 = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      assert_equal(cats1, cats2)
    end

    should "not equal another word if the phonetic components or meaning are different" do
      cats = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      assert_not_equal(cats, @dogs)
      cats_diff_meaning = PhoneticAlign::Word.new("cats",
                                    PhoneticAlign::FeatureValueMatrix[:LEMMA => :llama])
      assert_not_equal(cats, cats_diff_meaning)
      cats = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      kats = PhoneticAlign::Word.new("kats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      assert_not_equal(cats, kats)
    end

    should "be able to serve as a key in a hash table" do
      cats1 = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      cats2 = PhoneticAlign::Word.new("cats",
                                      PhoneticAlign::FeatureValueMatrix[:LEMMA => :cat,
                                                                        :NUMBER => :plural])
      h = {cats1 => :cats, @dogs => :dogs}
      assert_equal(:cats, h[cats1])
      assert_equal(:cats, h[cats2])
      assert_equal(:dogs, h[@dogs])
    end

    should "return the analyzed meaning for its morphemes" do
      all_phones = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert_equal(all_phones.analyzed_meaning, PhoneticAlign::FeatureValueMatrix.new)
      phone_and_morphs = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert_equal(phone_and_morphs.analyzed_meaning, @cat_morph.meaning)
      all_morphs = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert_equal(all_morphs.analyzed_meaning, @cats_meaning)
    end

    should "return the number of unanlyzed phones" do
      all_phones = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert_equal(all_phones.unanlayzed_phone_count, 4)
      phone_and_morphs = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert_equal(phone_and_morphs.unanlayzed_phone_count, 1)
      all_morphs = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert_equal(all_morphs.unanlayzed_phone_count, 0)
    end

    should "be fully-analyzed if its phonetic component consists entirely of morphemes" do
      all_phones = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert(!all_phones.fully_analyzed?)
      phone_and_morphs = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert(!phone_and_morphs.fully_analyzed?)
      all_morphs = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert(all_morphs.fully_analyzed?)
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

    should "have a transcription without the meaning matrix" do
      w = PhoneticAlign::Word.new([@c, @a, @t, @s], @cats_meaning)
      assert_equal("cats", w.transcription)
      w = PhoneticAlign::Word.new([@cat_morph, @s], @cats_meaning)
      assert_equal("[cat]s", w.transcription)
      w = PhoneticAlign::Word.new([@cat_morph, @s_morph], @cats_meaning)
      assert_equal("[cat][s]", w.transcription)
      z = PhoneticAlign::Phone.new("z")
      sz_morph = PhoneticAlign::Morpheme.new([[@s], [z]], @number_plural)
      w = PhoneticAlign::Word.new([@cat_morph, sz_morph], @cats_meaning)
      assert_equal("[cat][s/z]", w.transcription)
    end

  end
end


class FormFeatureReaderTestCase < Test::Unit::TestCase

  context "A Form-feature reader" do

    setup do
      @phones, @words = jumps_sees
    end

    should "ignore blank lines" do
      table = <<-EOTEXT

FORM, FEATURE

A, a

B, b

EOTEXT
      expected = [["A", {:FEATURE => :a}], ["B", {:FEATURE => :b}]]
      assert_equal(expected, PhoneticAlign::FormFeatureReader.new(table).collect)
    end

    should "read in a feature chart containing Unicode IPA symbols" do
      expected = [
          ["dʒ", {:VOWEL => :"-", :NASAL => :"-", :VOICED => :"+"}],
          ["m",  {:VOWEL => :"-", :NASAL => :"+", :VOICED => :"-"}],
          ["ŋ",  {:VOWEL => :"-", :NASAL => :"+", :VOICED => :"+"}],
          ["p",  {:VOWEL => :"-", :NASAL => :"-", :VOICED => :"-"}],
          ["s",  {:VOWEL => :"-", :NASAL => :"-", :VOICED => :"-"}],
          ["z",  {:VOWEL => :"-", :NASAL => :"-", :VOICED => :"+"}],
          ["i",  {:VOWEL => :"+", :NASAL => :"-", :VOICED => :"+"}],
          ["ʌ",  {:VOWEL => :"+", :NASAL => :"-", :VOICED => :"+"}]
        ]
      assert_equal(expected, PhoneticAlign::FormFeatureReader.new(@phones).collect)
    end

  end

end


class PhoneTableTestCase < Test::Unit::TestCase
  context "A PhoneTable" do
    setup do
      @phones = PhoneticAlign::PhoneTable.new(jumps_sees[0])
    end

    should "read in a feature chart containing Unicode IPA symbols" do
      expected = {
          "dʒ" => PhoneticAlign::Phone.new("dʒ".to_sym,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "m" => PhoneticAlign::Phone.new(:m,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "+".to_sym, :VOICED => "-".to_sym]),
          "ŋ" => PhoneticAlign::Phone.new("ŋ".to_sym,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "+".to_sym, :VOICED => "+".to_sym]),
          "p" => PhoneticAlign::Phone.new(:p,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "-".to_sym]),
          "s" => PhoneticAlign::Phone.new(:s,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "-".to_sym]),
          "z" => PhoneticAlign::Phone.new(:z,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "i" => PhoneticAlign::Phone.new(:i,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "+".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "ʌ" => PhoneticAlign::Phone.new("ʌ".to_sym,
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "+".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym])
        }
      assert_equal(expected.keys.sort, @phones.keys.sort)
      assert_equal(expected, @phones)
    end

    should "segment a string of unigraphs by character" do
      assert_equal([@phones["s"], @phones["i"], @phones["m"], @phones["i"], @phones["ŋ"]], @phones.phone_sequence("simiŋ"))
    end

    should "segment a string containing digraphs" do
      assert_equal([@phones["dʒ"], @phones["ʌ"], @phones["m"], @phones["p"]], @phones.phone_sequence("dʒʌmp"))
    end

    should "raise an exception for an unrecognized character" do
      assert_raise(ArgumentError) { @phones.phone_sequence("six") }
    end

    should "have a long stringification that prints the table in IPA order" do
      expected =<<-EOTEXT
dʒ [NASAL = -, VOICED = +, VOWEL = -]
i  [NASAL = -, VOICED = +, VOWEL = +]
m  [NASAL = +, VOICED = -, VOWEL = -]
p  [NASAL = -, VOICED = -, VOWEL = -]
s  [NASAL = -, VOICED = -, VOWEL = -]
z  [NASAL = -, VOICED = +, VOWEL = -]
ŋ [NASAL = +, VOICED = +, VOWEL = -]
ʌ [NASAL = -, VOICED = +, VOWEL = +]
EOTEXT
      # The fact that ŋ and ʌ appears to be a bug with the way sprintf
      # handles these characters.
      expected.strip!
      assert_equal(expected, @phones.to_s, "#{expected.to_s}\nexpected but was\n#{@phones.to_s}")
    end

    should "have a short stringification with the number of phones" do
      assert_equal("PhoneTable: 8 phones", @phones.inspect)
    end

    should "handle digraph phone names" do
      phone_data = """
FORM
a
bb
"""
      phone_table = PhoneticAlign::PhoneTable.new(phone_data)
      assert_equal(PhoneticAlign::Phone.new(:a), phone_table["a"])
      assert_equal(PhoneticAlign::Phone.new(:bb), phone_table["bb"])
      phones = phone_table.phone_sequence("abba")
      expected = [:a, :bb, :a].map { |s| PhoneticAlign::Phone.new(s) }
      assert_equal(expected, phones)
    end

    should "handle regular expression characters in phone names" do
      phone_data = """
FORM
a
.*
"""
      phone_table = PhoneticAlign::PhoneTable.new(phone_data)
      assert_equal(PhoneticAlign::Phone.new(:a), phone_table["a"])
      assert_equal(PhoneticAlign::Phone.new(:".*"), phone_table[".*"])
      phones = phone_table.phone_sequence("a.*a")
      expected = [:a, :".*", :a].map { |s| PhoneticAlign::Phone.new(s) }
      assert_equal(expected, phones)
    end
  end

end


class WordListTestCase < Test::Unit::TestCase

  context "A Word list" do

    setup do
      @phones, @words = jumps_sees
    end

    should "be creatable from a word list and phone table string" do
      word_list = PhoneticAlign::WordList.new(@words, @phones)
      transcriptions = ["dʒʌmp", "dʒʌmps", "dʒʌmpiŋ", "si", "siz", "siiŋ"]
      assert_equal(transcriptions, word_list.collect { |w| w.transcription })
      # jump is the first word in the list
      jump = word_list.first
      # Verify the semantic features of jump
      assert_equal({:LEMMA => :jump, :PERNUM => :"non-3sg", :ASPECT => :perfect}, jump.meaning)
      # Verify segments on jump
      assert_equal(["dʒ".to_sym, "ʌ".to_sym, :m, :p], jump.phonetic_component.collect { |p| p.ipa })
      # Verify the phonetic featuers of the first segment in jump
      assert_equal({:VOWEL => :"-", :NASAL => :"-", :VOICED => :"+"}, jump.phonetic_component.first.features)
    end

    should "be creatable from a word list and a phone table" do
      phone_table = PhoneticAlign::PhoneTable.new(@phones)
      word_list = PhoneticAlign::WordList.new(@words, phone_table)
      transcriptions = ["dʒʌmp", "dʒʌmps", "dʒʌmpiŋ", "si", "siz", "siiŋ"]
      assert_equal(transcriptions, word_list.collect { |w| w.transcription })
      # jump is the first word in the list
      jump = word_list.first
      # Verify the semantic features of jump
      assert_equal({:LEMMA => :jump, :PERNUM => :"non-3sg", :ASPECT => :perfect}, jump.meaning)
      # Verify segments on jump
      assert_equal(["dʒ".to_sym, "ʌ".to_sym, :m, :p], jump.phonetic_component.collect { |p| p.ipa })
      # Verify the phonetic featuers of the first segment in jump
      assert_equal({:VOWEL => :"-", :NASAL => :"-", :VOICED => :"+"}, jump.phonetic_component.first.features)
    end

    should "be creatable from a word list without a phone table" do
      word_list = PhoneticAlign::WordList.new(@words)
      transcriptions = ["dʒʌmp", "dʒʌmps", "dʒʌmpiŋ", "si", "siz", "siiŋ"]
      assert_equal(transcriptions, word_list.collect { |w| w.transcription })
      djump = word_list.first
      assert_equal({:LEMMA => :jump, :PERNUM => :"non-3sg", :ASPECT => :perfect}, djump.meaning)
      djump_form = "dʒʌmp".split("").collect { |f| PhoneticAlign::Phone.new(f, {}) }
      assert_equal(djump_form, djump.phonetic_component)
    end

    should "raise a RuntimeError if either of its intialization tables does not contain a FORM column" do
      no_form_data = "COL A, COL B\na,b"
      assert_raise(RuntimeError) { PhoneticAlign::WordList.new(no_form_data) }
      assert_raise(RuntimeError) { PhoneticAlign::WordList.new(@words, no_form_data) }
    end

    should "raise an ArgumentError if a word contains a segment not in the phone table" do
      bad_phone_data = "FORM, LEMMA, PERNUM, ASPECT\ndʒʌXp,jump, non-3sg, perfect"
      assert_raise(ArgumentError) { PhoneticAlign::WordList.new(@words, bad_phone_data) }
    end

    should "ignore missing final fields in a line of the table" do
      short_line = "FORM, LEMMA\ndʒump"
      w = PhoneticAlign::WordList.new(short_line)
      assert_equal(1, w.length)
      assert_instance_of(PhoneticAlign::Word, w.first)
      assert_equal({}, w.first.meaning)
    end

  end

end


class AlignmentTestCase < Test::Unit::TestCase
  context "Alignments" do
    setup do
      words = happy_unhappy_unhappiness
      # All phones.
      @happy_p = words.happy_p
      @unhappy_p = words.unhappy_p
      @unhappiness_p = words.unhappiness_p
      # Phones and morphemes.
      @unhappy_pm = words.unhappy_pm
      # All morphemes
      @happy_m = words.happy_m
      @unhappy_m = words.unhappy_m
      @happy_happi_ness_m = words.happy_happi_ness_m
    end

    should "align phones with phones" do
      # --happy
      # unhappy
      # II
      align = PhoneticAlign::Alignment.new(@happy_p, @unhappy_p)
      assert_equal(2, align.edit_distance)
      assert_equal([:insert, :insert, nil, nil, nil, nil, nil], align.edit_operations, align)
    end

    should "align morphemes and morphemes" do
      #  -  happy
      # un  happy
      #  I
      align = PhoneticAlign::Alignment.new(@happy_m, @unhappy_m)
      assert_equal(1, align.edit_distance)
      assert_equal([:insert, nil], align.edit_operations, align)
    end

    should "align compatible allomorphs" do
      # un        happy        -
      #  -     happi/happy   ness
      #  D          S         I
      align = PhoneticAlign::Alignment.new(@unhappy_m, @happy_happi_ness_m)
      assert_equal(2, align.edit_distance)
      assert_equal([:delete, :substitute, :insert], align.edit_operations, align)
    end

    should "not align phones with morphemes" do
      # u - n h a p p y
      # - un- h a p p y
      # D I D
      #
      # Note that this alignment is not ideal.  The morpheme un splits the
      # character sequence u,n.
      align = PhoneticAlign::Alignment.new(@unhappy_p, @unhappy_pm)
      assert_equal(3, align.edit_distance)
      assert_equal([:delete, :insert, :delete, nil, nil, nil, nil, nil], align.edit_operations, align)
    end

    should "define a length function equal to the number of slots" do
      @happy_unhappy = PhoneticAlign::Alignment.new(@happy_p, @unhappy_p)
      @happy_unhappiness = PhoneticAlign::Alignment.new(@happy_p, @unhappiness_p)
      assert_equal(11, @happy_unhappiness.length)
      assert_equal(7, @happy_unhappy.length)
    end

  end

  context "Stringification of segmented alignments" do
    setup do
      words = happy_unhappy_unhappiness
      @unhappy_unhappiness = PhoneticAlign::Alignment.new(words.unhappy_p, words.unhappiness_p)
    end

    should "put vertical bars on the segment boundaries" do
      expected =<<-EOTEXT
un|happy|----
un|happi|ness
  |    S|IIII
0.5455
EOTEXT
      assert_equal(expected.strip, @unhappy_unhappiness.to_s([2,7]))
    end

    should "not put vertical bars in unsegmented words" do
      expected =<<-EOTEXT
unhappy----
unhappiness
      SIIII
0.5455
EOTEXT
      assert_equal(expected.strip, @unhappy_unhappiness.to_s)
    end

    should "optionally write carets under emphasized segments" do
      first_segment =<<-EOTEXT
un|happy|----
un|happi|ness
  |    S|IIII
^^|     |    
0.5455
EOTEXT
      actual = @unhappy_unhappiness.to_s([2,7], [0,1])
      assert_equal(first_segment.strip, actual, "#{first_segment.strip}\nnot\n#{actual}")
      middle_segment =<<-EOTEXT
un|happy|----
un|happi|ness
  |    S|IIII
  |^^^^^|    
0.5455
EOTEXT
      actual = @unhappy_unhappiness.to_s([2,7], [2,6])
      assert_equal(middle_segment.strip, actual, "#{middle_segment.strip}\nnot\n#{actual}")
      last_segment =<<-EOTEXT
un|happy|----
un|happi|ness
  |    S|IIII
  |     |^^^^
0.5455
EOTEXT
      actual = @unhappy_unhappiness.to_s([2,7], [7, 10])
      assert_equal(last_segment.strip, actual, "#{last_segment.strip}\nnot\n#{actual}")
    end

  end

end


class SegementationTestCase < Test::Unit::TestCase

  context "Segmentations" do
    setup do
      words = happy_unhappy_unhappiness
      @happy_unhappy = PhoneticAlign::Alignment.new(words.happy_p, words.unhappy_p)
      @happy_unhappiness = PhoneticAlign::Alignment.new(words.happy_p, words.unhappiness_p)
    end

    should "return segment ranges given segment indexes" do
      segments = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      assert_equal(3, segments.length)
      # --|happy|----
      # un|happi|ness
      # II|    S|IIII
      assert_equal(0, segments[0].from)
      assert_equal(1, segments[0].to)
      assert_equal(2, segments[1].from)
      assert_equal(6, segments[1].to)
      assert_equal(7, segments[2].from)
      assert_equal(10, segments[2].to)
    end

    should "access segments either by [] or enumeration" do
      segmentation = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      segments = segmentation.collect
      assert_equal(segments[0], segmentation[0])
      assert_equal(segments[1], segmentation[1])
      assert_equal(segments[2], segmentation[2])
    end

    should "be equal if they are from the same alignment and have the same boundaries" do
      segmentation1 = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      segmentation2 = @happy_unhappiness.segmentation(0.6) # dist(i,y) <= 0.6
      assert_equal(segmentation1, segmentation2)
    end

    should "have phonetic operation lists that represent phone substitutions" do
      segments = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      # --|happy|----
      # un|happi|ness
      # II|    S|IIII
      # y <-> i is a substitution in the edit operations but a nil in the
      # phonetic operations.
      assert_equal([:insert]*2 + [nil]*4 + [:substitute] + [:insert]*4,
                   segments.edit_operations)
      assert_equal([:insert]*2 + [nil]*5 + [:insert]*4,
                   segments.phonetic_operations)
    end

    should "insert boundaries at edit operation discontinuities" do
      segments = @happy_unhappy.segmentation
      # --|happy
      # un|happy
      # II|
      assert_equal(2, segments.length)
      assert_equal([2], segments.segment_boundaries)
    end

    should "treat phone substitutions beneath a threshold as matching" do
      segments = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      # --|happy|----
      # un|happi|ness
      # II|    S|IIII
      assert_equal(3, segments.length)
      assert_equal([2, 7], segments.segment_boundaries)
    end

    should "not treat phone substitutions as matching if the distance is too large" do
      segments = @happy_unhappiness.segmentation(0.2) # dist(i,y) > 0.5
      # --|happ|y|----
      # un|happ|i|ness
      # II|    |S|IIII
      assert_equal(4, segments.length)
      assert_equal([2, 6, 7], segments.segment_boundaries)
    end

    should "calculate match rate based on phonetic operations" do
      segments = @happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
      # --|happ|y|----
      # un|happ|i|ness
      # II|    |S|IIII
      assert_in_delta(Rational(5, 11), segments.match_rate, 2 ** -20)
      segments = @happy_unhappiness.segmentation(0.2) # dist(i,y) > 0.5
      # --|happ|y|----
      # un|happ|i|ness
      # II|    |S|IIII
      assert_in_delta(Rational(4, 11), segments.match_rate, 2 ** -20)
    end

  end

end


class SegementTestCase < Test::Unit::TestCase
  context "Segments" do
    setup do
      words = happy_unhappy_unhappiness
      @happy_p = words.happy_p
      @unhappiness_p = words.unhappiness_p
      happy_unhappiness = PhoneticAlign::Alignment.new(@happy_p, @unhappiness_p)
      # --|happy|----
      # un|happi|ness
      # II|    S|IIII
      @segments = happy_unhappiness.segmentation(0.5) # dist(i,y) <= 0.5
    end

    should "have one more segment than there are segment boundaries" do
      assert_equal(3, @segments.length)
    end

    should "be equal if and only if they have the same alignment and to and from offsets" do
      assert_equal(@segments[0], @segments[0])
      assert_not_equal(@segments[0], @segments[1])
    end

    should "be phonetically same if they have all nil phonetic edit operations" do
      assert_equal(false, @segments[0].phonetically_same?,
                   "phonetically_same?\n#{@segments[0]}")
      assert_equal(true, @segments[1].phonetically_same?,
                   "phonetically_same?\n#{@segments[1]}")
      assert_equal(false, @segments[2].phonetically_same?,
                   "phonetically_same?\n#{@segments[2]}")
    end

    should "be phonetically different if they have any non-nil phonetic edit operations" do
      assert_equal(true, @segments[0].phonetically_different?,
                   "phonetically_different?\n#{@segments[0]}")
      assert_equal(false, @segments[1].phonetically_different?,
                   "phonetically_different?\n#{@segments[0]}")
      assert_equal(true, @segments[2].phonetically_different?,
                   "phonetically_different?\n#{@segments[0]}")
    end

    should "make the phonetic component of each word available" do
      # happy
      assert_equal([nil] * 2, @segments[0].phonetic_component(:source))
      assert_equal(@happy_p.phonetic_component, @segments[1].phonetic_component(:source))
      assert_equal([nil] * 4, @segments[2].phonetic_component(:source))
      # unhappiness
      assert_equal(@unhappiness_p.phonetic_component[0..1], @segments[0].phonetic_component(:dest))
      assert_equal(@unhappiness_p.phonetic_component[2..6], @segments[1].phonetic_component(:dest))
      assert_equal(@unhappiness_p.phonetic_component[7..10], @segments[2].phonetic_component(:dest))
    end
    
    should "not have a meaning if they do not consist of morphemes" do
      # happy
      assert_equal(nil, @segments[0].meaning(:source))
      assert_equal(nil, @segments[1].meaning(:source))
      assert_equal(nil, @segments[2].meaning(:source))
      # unhappiness
      assert_equal(nil, @segments[0].meaning(:dest))
      assert_equal(nil, @segments[1].meaning(:dest))
      assert_equal(nil, @segments[2].meaning(:dest))
    end
    
    should "say whether or not their phonetic component consists entirely of phones" do
      assert_equal(true, @segments[1].is_phones?(:source))
      assert_equal(true, @segments[0].is_phones?(:dest))
      assert_equal(true, @segments[1].is_phones?(:dest))
      assert_equal(true, @segments[2].is_phones?(:dest))
    end
    
    should "stringify with the segment emphasized" do
      expected =<<-EOTEXT
--|happy|----
un|happi|ness
II|    S|IIII
^^|     |    
0.3636
EOTEXT
      assert_equal(expected.strip, @segments[0].to_s, "Expected\n#{expected}\nbut got\n#{@segments[0]}")
            expected =<<-EOTEXT
--|happy|----
un|happi|ness
II|    S|IIII
  |^^^^^|    
0.3636
EOTEXT
      assert_equal(expected.strip, @segments[1].to_s, "Expected\n#{expected}\nbut got\n#{@segments[1]}")
      expected =<<-EOTEXT
--|happy|----
un|happi|ness
II|    S|IIII
  |     |^^^^
0.3636
EOTEXT
      assert_equal(expected.strip, @segments[2].to_s, "Expected\n#{expected}\nbut got\n#{@segments[2]}")
    end
  end

  context "Segments containing morphemes" do
    setup do
      words = happy_unhappy_unhappiness
      @happy_m = words.happy_m
      @unhappy_happi_ness_m = words.unhappy_happi_ness_m
      @un_meaning = words.un_meaning
      @happy_meaning = words.happy_meaning
      @ness_meaning = words.ness_meaning
      happy_unhappiness = PhoneticAlign::Alignment.new(@happy_m, @unhappy_happi_ness_m)
      #  -          |        happy        |          -
      # un          |     happi/happy     |        ness
      #  I          |                     |          I
      @segments = happy_unhappiness.segmentation
    end

    should "make their meanings available" do
      assert_equal(3, @segments.length)
      # happy
      assert_equal(nil, @segments[0].meaning(:source))
      assert_equal(@happy_meaning, @segments[1].meaning(:source))
      assert_equal(nil, @segments[2].meaning(:source))
      # unhappiness
      assert_equal(@un_meaning, @segments[0].meaning(:dest))
      assert_equal(@happy_meaning, @segments[1].meaning(:dest))
      assert_equal(@ness_meaning, @segments[2].meaning(:dest))
    end
    
    should "say that their phonetic components do not consist of phones" do
      assert_equal(false, @segments[1].is_phones?(:source))
      assert_equal(false, @segments[0].is_phones?(:dest))
      assert_equal(false, @segments[1].is_phones?(:dest))
      assert_equal(false, @segments[2].is_phones?(:dest))
    end

  end

end


class MorphemeHypothesisTestCase < Test::Unit::TestCase
  context "Morpheme hypotheses" do
    setup do
      words = happy_unhappy_unhappiness
      @phone_table = words.phone_table
      happy_unhappy = PhoneticAlign::Alignment.new(words.happy_p, words.unhappy_p).segmentation(0.5) # dist(i,y) <= 0.5
      happy_unhappiness = PhoneticAlign::Alignment.new(words.happy_p, words.unhappiness_p).segmentation(0.5) # dist(i,y) <= 0.5
      happy_morph = PhoneticAlign::Morpheme.new([happy_unhappy[1].phonetic_component(:source)], words.happy_meaning)
      @happy1 = PhoneticAlign::MorphemeHypothesis.new(happy_unhappy[1], :source, happy_morph)
      happy_happi_morph = PhoneticAlign::Morpheme.new([happy_unhappiness[1].phonetic_component(:source),
                                                       happy_unhappiness[1].phonetic_component(:dest)], words.happy_meaning)
      @happy2 = PhoneticAlign::MorphemeHypothesis.new(happy_unhappiness[1], :source, happy_happi_morph)
      @happi = PhoneticAlign::MorphemeHypothesis.new(happy_unhappiness[1], :dest, happy_happi_morph)
    end
    
    should "contain Morpheme objects" do
      # happy: [LEMMA = happy]
      # --|happy <==
      # un|happy
      # II|     
      #   |^^^^^
      # 0.7143
      expected = PhoneticAlign::Morpheme.new([@phone_table.phone_sequence("happy")],
                                             PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(expected, @happy1.morpheme)
      # happi/happy: [LEMMA = happy]
      # --|happy|---- <==
      # un|happi|ness
      # II|    S|IIII
      #   |^^^^^|    
      # 0.3636
      expected = PhoneticAlign::Morpheme.new([@phone_table.phone_sequence("happy"),
                                              @phone_table.phone_sequence("happi")],
                                             PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(expected, @happy2.morpheme)
      # happi/happy: [LEMMA = happy]
      # --|happy|----
      # un|happi|ness <==
      # II|    S|IIII
      #   |^^^^^|    
      # 0.3636
      expected = PhoneticAlign::Morpheme.new([@phone_table.phone_sequence("happy"),
                                              @phone_table.phone_sequence("happi")],
                                             PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(expected, @happi.morpheme)
    end
    
    should "send unhandled calls down to their morpheme objects" do
      assert_equal(@happy1.meaning, PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(@happy2.meaning, PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal(@happi.meaning, PhoneticAlign::FeatureValueMatrix[:LEMMA => :happy])
      assert_equal("[happy]", @happy1.transcription)
      assert_equal("[happi/happy]", @happy2.transcription)
      assert_equal("[happi/happy]", @happi.transcription)
    end    
    
    should "have the match rate of the alignment as an attribute" do
      assert_in_delta(Rational(5,7), @happy1.match_rate, 2 ** -20)
      assert_in_delta(Rational(5,11), @happy2.match_rate, 2 ** -20)
      assert_in_delta(Rational(5,11), @happi.match_rate, 2 ** -20)
    end
    
    should "stringify with their segment emphasized and an arrow pointing at the word" do
      expected = <<-EOTEXT
[happy]: [LEMMA = happy]
--|happy <==
un|happy
II|     
  |^^^^^
0.7143
EOTEXT
      assert_equal(expected.strip, @happy1.to_s, "Expected\n#{expected.strip}\nGot\n#{@happy1.to_s}")
      expected = <<-EOTEXT
[happi/happy]: [LEMMA = happy]
--|happy|---- <==
un|happi|ness
II|    S|IIII
  |^^^^^|    
0.3636
EOTEXT
      assert_equal(expected.strip, @happy2.to_s, "Expected\n#{expected.strip}\nGot\n#{@happy2.to_s}")
      expected = <<-EOTEXT
[happi/happy]: [LEMMA = happy]
--|happy|----
un|happi|ness <==
II|    S|IIII
  |^^^^^|    
0.3636
EOTEXT
      assert_equal(expected.strip, @happi.to_s, "Expected\n#{expected.strip}\nGot\n#{@happi.to_s}")
    end
  end

end


class CreeTestCase < Test::Unit::TestCase
  def setup
    data_dir = File.join(File.dirname(__FILE__), "..", "data")
    @cree_phones = open(File.join(data_dir, "cree.phones")) do |file|
      PhoneticAlign::PhoneTable.new(file)
    end
    @cree_words = open(File.join(data_dir, "cree.words")) do |file|
      PhoneticAlign::WordList.new(file, @cree_phones)
    end
    @atim = @cree_words.find { |w| w.transcription == "atim" }
    @atimwak = @cree_words.find { |w| w.transcription == "atimwak" }
    @atimwa = @cree_words.find { |w| w.transcription == "atimwa" }
  end

  context "The first iteration over the Cree data" do

    should "have atim, atimwak, and atimwa in the word list" do
      assert_instance_of(PhoneticAlign::Word, @atim)
      assert_equal(PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog, :NUMBER => :singular, :DISTANCE => :proximate],
                   @atim.meaning)
      assert_instance_of(PhoneticAlign::Word, @atimwak)
      assert_equal(PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog, :NUMBER => :plural, :DISTANCE => :proximate],
                  @atimwak.meaning)
      assert_equal(PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog, :NUMBER => :singular, :DISTANCE => :obviate],
                  @atimwa.meaning)
      assert_instance_of(PhoneticAlign::Word, @atimwa)
    end
    
    should "get morpheme hypotheses for atim and wak from the atim/atimwak alignment" do
      # Alignment
      atim_atimwak = PhoneticAlign::Alignment.new(@atim, @atimwak)
      assert_in_delta(Rational(4,7), atim_atimwak.match_rate, 2 ** -20)
      segments = atim_atimwak.segmentation
      # Segmentation
      # atim|---
      # atim|wak
      #     |III
      assert_equal(2, segments.length)
      assert(segments[0].phonetically_same?)
      assert(segments[1].phonetically_different?)
      # Morpheme hypotheses
      morpheme_hyps = []
      segments.each_morpheme_hypothesis {|hyp| morpheme_hyps << hyp}
      assert_equal(4, morpheme_hyps.length)
      # wak: [NUMBER = plural]
      # atim|---
      # atim|wak <==
      #     |III
      #     |^^^
      # 0.5714
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("wak")],
                                          PhoneticAlign::FeatureValueMatrix[:NUMBER => :plural])
      wak_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[1], :dest, morph)
      assert_equal(wak_hyp, morpheme_hyps[0], "Expected\n#{wak_hyp}\nGot\n#{morpheme_hyps[0]}")
      # atim: [DISTANCE = proximate, LEMMA = dog]
      # atim|--- <==
      # atim|wak
      #     |III
      # ^^^^|   
      # 0.5714
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :DISTANCE => :proximate])
      atim_source_hyp1 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atim_source_hyp1, morpheme_hyps[1], "Expected\n#{atim_source_hyp1}\nGot\n#{morpheme_hyps[1]}")
      # atim: [DISTANCE = proximate, LEMMA = dog]
      # atim|---
      # atim|wak <==
      #     |III
      # ^^^^|   
      # 0.5714
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :DISTANCE => :proximate])
      atim_dest_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[0], :dest, morph)
      assert_equal(atim_dest_hyp, morpheme_hyps[2], "Expected\n#{atim_dest_hyp}\nGot\n#{morpheme_hyps[2]}")
      # atim: [DISTANCE = proximate, LEMMA = dog, NUMBER = singular]
      # atim|--- <==
      # atim|wak
      #     |III
      # ^^^^|   
      # 0.5714
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :DISTANCE => :proximate,
                                                                            :NUMBER => :singular])
      atim_source_hyp2 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atim_source_hyp2, morpheme_hyps[3], "Expected\n#{atim_source_hyp2}\nGot\n#{morpheme_hyps[3]}")
    end
    
    should "get morpheme hypotheses for atim and wa from the atim/atimwa alignment" do
      # Alignment
      # atim|--
      # atim|wa
      #     |II
      atim_atimwa = PhoneticAlign::Alignment.new(@atim, @atimwa)
      assert_in_delta(Rational(4,6), atim_atimwa.match_rate, 2 ** -20)
      segments = atim_atimwa.segmentation
      # Segmentation
      assert_equal(2, segments.length)
      assert(segments[0].phonetically_same?)
      assert(segments[1].phonetically_different?)
      # Morpheme hypotheses
      morpheme_hyps = []
      segments.each_morpheme_hypothesis {|hyp| morpheme_hyps << hyp}
      assert_equal(4, morpheme_hyps.length)
      # wa: [DISTANCE = obviate]
      # atim|--
      # atim|wa <==
      #     |II
      #     |^^
      # 0.6667
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("wa")],
                                          PhoneticAlign::FeatureValueMatrix[:DISTANCE => :obviate])
      wa_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[1], :dest, morph)
      assert_equal(wa_hyp, morpheme_hyps[0], "Expected\n#{wa_hyp}\nGot\n#{morpheme_hyps[0]}")
      # atim: [LEMMA = dog, NUMBER = singular]
      # atim|-- <==
      # atim|wa
      #     |II
      # ^^^^|  
      # 0.6667
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")], 
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :NUMBER => :singular])
      atim_source_hyp1 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atim_source_hyp1, morpheme_hyps[1], "Expected\n#{atim_source_hyp1}\nGot\n#{morpheme_hyps[1]}")
      # atim: [LEMMA = dog, NUMBER = singular]
      # atim|--
      # atim|wa <==
      #     |II
      # ^^^^|  
      # 0.6667
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")], 
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :NUMBER => :singular])
      atim_dest_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[0], :dest, morph)
      assert_equal(atim_dest_hyp, morpheme_hyps[2], "Expected\n#{atim_dest_hyp}\nGot\n#{morpheme_hyps[2]}")
      # atim: [LEMMA = dog, DISTANCE = proximate, NUMBER = singular]
      # atim|-- <==
      # atim|wa
      #     |II
      # ^^^^|  
      # 0.6667
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")], 
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :DISTANCE => :proximate,
                                                                            :NUMBER => :singular])
      atim_source_hyp2 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atim_source_hyp2, morpheme_hyps[3], "Expected\n#{atim_source_hyp2}\nGot\n#{morpheme_hyps[3]}")
    end
    
    should "get morpheme hypotheses for atimwa and k from the atimwa/atimwak alignment" do
      # Alignment
      atimwa_atimwak = PhoneticAlign::Alignment.new(@atimwa, @atimwak)
      assert_in_delta(Rational(6,7), atimwa_atimwak.match_rate, 2 ** -20)
      segments = atimwa_atimwak.segmentation
      # Segmentation
      # atimwa|
      # atimwa|k
      #       |I
      # 0.8571
      assert_equal(2, segments.length)
      assert(segments[0].phonetically_same?)
      assert(segments[1].phonetically_different?)
      # Morpheme hypotheses
      morpheme_hyps = []
      segments.each_morpheme_hypothesis {|hyp| morpheme_hyps << hyp}
      assert_equal(4, morpheme_hyps.length)
      # k: [DISTANCE = proximate, NUMBER = plural]
      # atimwa|-
      # atimwa|k <==
      #       |I
      #       |^
      # 0.8571
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("k")],
                                          PhoneticAlign::FeatureValueMatrix[:NUMBER => :plural,
                                                                            :DISTANCE => :proximate])
      k_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[1], :dest, morph)
      assert_equal(k_hyp, morpheme_hyps[0], "Expected\n#{k_hyp}\nGot#{morpheme_hyps[0]}")
      # atimwa: [LEMMA = dog]
      # atimwa|- <==
      # atimwa|k
      #       |I
      # ^^^^^^| 
      # 0.8571
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atimwa")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog])
      atimwa_source_hyp1 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atimwa_source_hyp1, morpheme_hyps[1], "Expected\n#{atimwa_source_hyp1}\nGot\n#{morpheme_hyps[1]}")
      # atimwa: [LEMMA = dog]
      # atimwa|-
      # atimwa|k <==
      #       |I
      # ^^^^^^| 
      # 0.8571
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atimwa")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog])
      atimwa_dest_hyp = PhoneticAlign::MorphemeHypothesis.new(segments[0], :dest, morph)
      assert_equal(atimwa_dest_hyp, morpheme_hyps[2], "Expected\n#{atimwa_dest_hyp}\nGot\n#{morpheme_hyps[2]}")
      # atimwa: [LEMMA = dog]
      # atimwa|- <==
      # atimwa|k
      #       |I
      # ^^^^^^| 
      # 0.8571
      morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atimwa")],
                                          PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog,
                                                                            :DISTANCE => :obviate,
                                                                            :NUMBER => :singular])
      atimwa_source_hyp2 = PhoneticAlign::MorphemeHypothesis.new(segments[0], :source, morph)
      assert_equal(atimwa_source_hyp2, morpheme_hyps[3], "Expected\n#{atimwa_source_hyp2}\nGot\n#{morpheme_hyps[3]}")
    end

  end

  context "The Cree words without the phones file" do
    setup do
      data_dir = File.join(File.dirname(__FILE__), "..", "data")
      @cree_words = open(File.join(data_dir, "cree.words")) do |file|
        PhoneticAlign::WordList.new(file)
      end
      @atim = @cree_words.find { |w| w.transcription == "atim" }
      @atimwak = @cree_words.find { |w| w.transcription == "atimwak" }
      @atimwa = @cree_words.find { |w| w.transcription == "atimwa" }
    end
    
    should "should treat all atim allomorphs as the same hash key" do
      atimwak_atim = PhoneticAlign::Alignment.new(@atimwak, @atim).segmentation
      atimwa_atim = PhoneticAlign::Alignment.new(@atimwa, @atim).segmentation
      # Extract all the atim allomorphs.
      hyps = []
      [atimwak_atim, atimwa_atim].each do |s|
        s.each_morpheme_hypothesis {|hyp| hyps << hyp}
      end
      hyps = hyps.find_all { |hyp| hyp.transcription == "[atim]" }
      # Hyps 0 and 1 come from one alignment. Hyps 2 and 3 come from the other
      # alignment.
      # They should all be equal to each other.
      assert_equal(hyps[0].allophones, hyps[1].allophones)
      assert_equal(hyps[2].allophones, hyps[3].allophones)
      assert_equal(hyps[0].allophones, hyps[2].allophones)
      assert_equal(hyps[0].allophones, hyps[3].allophones)
      assert_equal(hyps[1].allophones, hyps[2].allophones)
      assert_equal(hyps[1].allophones, hyps[3].allophones)
      # They should also all map to the same hash key.
      h = {hyps[0].allophones => :value}
      assert_equal(h[hyps[0].allophones], :value)
      assert_equal(h[hyps[1].allophones], :value)
      assert_equal(h[hyps[2].allophones], :value)
      assert_equal(h[hyps[3].allophones], :value)
      # If Phone does not define its own hash and eql? function, these tests
      # will fail.
      #
      # I haven't been able to find any scenario that reproduces this bug
      # except for the one in this test.
      #
      # I would expect the simpler "A cloned Phone sequence" scenario in the
      # Phone test case to also catch this bug, but it does not for reasons I
      # don't understand.
    end
    
  end

  context "The words [atim]wa and [atim]wak with morpheme [atim]" do
    should "insert boundary after [atim] morpheme" do
      atim_meaning = PhoneticAlign::FeatureValueMatrix[:LEMMA => :dog]
      atim_morph = PhoneticAlign::Morpheme.new([@cree_phones.phone_sequence("atim")],
                                               atim_meaning)
      @atimwa.phonetic_component[0..3] = atim_morph
      @atimwak.phonetic_component[0..3] = atim_morph
      alignment = PhoneticAlign::Alignment.new(@atimwa, @atimwak)
      # [atim]  |     w     a     |     -   
      # [atim]  |     w     a     |     k   
      #         |                 |     I   
      # 0.8571
      segmentation = alignment.segmentation
      assert_equal(3, segmentation.length)
      assert_equal(segmentation.segment_boundaries, [1,3])
    end
  end

  context "Two morpheme hypotheses from very different alignments" do
    # These two morpheme hypotheses:
    #
    # [wa]: [DISTANCE = obviate]
    #    a      |      -      |      t      i      |      m   
    #    -      |   [amisk]   |      w      a      |      -    <==
    #    D      |      I      |      S      S      |      D   
    #           |             |   ^^^^^^^^^^^^^^   |          
    # 0.5556
    # [wa]: [DISTANCE = obviate]
    # [amisk]   |      w      a    <==
    # [amisk]   |      -      -   
    #           |      D      D   
    #           |   ^^^^^^^^^^^^^^
    # 0.7143
    #
    # should be equal
    should "be equal if they propose the same morpheme for the same portion of the same word" do
      # Read the words out of the Cree word list and insert the [amisk] morpheme.
      amisk = @cree_words.find { |w| w.transcription == "amisk" }
      amisk.phonetic_component = [PhoneticAlign::Morpheme.new([amisk.phonetic_component],
        PhoneticAlign::FeatureValueMatrix[:LEMMA => :beaver])]
      amiskwa = @cree_words.find { |w| w.transcription == "amiskwa" }
      amiskwa.phonetic_component[0..4] = PhoneticAlign::Morpheme.new([amiskwa.phonetic_component[0..4]],
        PhoneticAlign::FeatureValueMatrix[:LEMMA => :beaver])
      # Align and segment atim/[amisk]wa and [amisk]wa/[amisk].
      atim_amiskwa = PhoneticAlign::Alignment.new(@atim, amiskwa).segmentation
      amiskwa_amisk = PhoneticAlign::Alignment.new(amiskwa, amisk).segmentation
      # Create [wa] morpheme hypotheses from the two alignments.
      wa1 = PhoneticAlign::MorphemeHypothesis.new(atim_amiskwa[2], :dest,
        PhoneticAlign::Morpheme.new(["wa"], PhoneticAlign::FeatureValueMatrix[:DISTANCE => :obviate]))
      wa2 = PhoneticAlign::MorphemeHypothesis.new(amiskwa_amisk[1], :source,
        PhoneticAlign::Morpheme.new(["wa"], PhoneticAlign::FeatureValueMatrix[:DISTANCE => :obviate]))
      # The two [wa] morpheme hypotheses should  be equal because they propose
      # the same morpheme for the same portion of the same word.
      assert_equal(wa1, wa2, "#{wa1}\nnot equal to\n#{wa2}")
    end
  end

end
