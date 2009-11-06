require "helper"


$segments =<<-EOTEXT
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

$words =<<-EOTEXT
FORM, LEMMA, PERNUM, ASPECT
dʒʌmp,jump, non-3sg, perfect
dʒʌmps,jump, 3sg, perfect
dʒʌmpiŋ,jump,, imperfect
si,see, non-3sg, perfect
siz,see, 3sg, perfect
siiŋ,see,, imperfect
EOTEXT


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

    should "Equal another phone with the same IPA and features" do
      features = PhoneticAlign::FeatureValueMatrix[:f1 => :v1, :f2 => :v2]
      p1 = PhoneticAlign::Phone.new("p", features)
      p2 = PhoneticAlign::Phone.new("p", features)
      assert(p1 == p2, "#{p1} != #{p2}")
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
      assert_equal("dʒ [f1 = v1, f2 = v2]", @j.to_s)
    end

    should "stringify with an optional IPA field width" do
      assert_equal("dʒ   [f1 = v1, f2 = v2]", @j.to_s(5))
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

    should "have a transcription without the feature matrix" do
      assert_equal("s", @s.transcription)
      assert_equal("s/z", @sz.transcription)
      assert_equal("ed", @ed.transcription)
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

    should "read in a feature chart containing Unicode IPA symbols" do
      expected = [
          ["dʒ", {"VOWEL" => "-", "NASAL" => "-", "VOICED" => "+"}],
          ["m",  {"VOWEL" => "-", "NASAL" => "+", "VOICED" => "-"}],
          ["ŋ",  {"VOWEL" => "-", "NASAL" => "+", "VOICED" => "+"}],
          ["p",  {"VOWEL" => "-", "NASAL" => "-", "VOICED" => "-"}],
          ["s",  {"VOWEL" => "-", "NASAL" => "-", "VOICED" => "-"}],
          ["z",  {"VOWEL" => "-", "NASAL" => "-", "VOICED" => "+"}],
          ["i",  {"VOWEL" => "+", "NASAL" => "-", "VOICED" => "+"}],
          ["ʌ",  {"VOWEL" => "+", "NASAL" => "-", "VOICED" => "+"}]
        ]
      assert_equal(expected, PhoneticAlign::FormFeatureReader.new($segments).collect)
    end

  end

end


class PhoneTableTestCase < Test::Unit::TestCase
  context "A PhoneTable" do
    setup do
      @phones = PhoneticAlign::PhoneTable.new($segments)
    end

    should "read in a feature chart containing Unicode IPA symbols" do
      expected = {
          "dʒ" => PhoneticAlign::Phone.new("dʒ",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "m" => PhoneticAlign::Phone.new("m",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "+".to_sym, :VOICED => "-".to_sym]),
          "ŋ" => PhoneticAlign::Phone.new("ŋ",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "+".to_sym, :VOICED => "+".to_sym]),
          "p" => PhoneticAlign::Phone.new("p",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "-".to_sym]),
          "s" => PhoneticAlign::Phone.new("s",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "-".to_sym]),
          "z" => PhoneticAlign::Phone.new("z",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "-".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "i" => PhoneticAlign::Phone.new("i",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "+".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym]),
          "ʌ" => PhoneticAlign::Phone.new("ʌ",
                  PhoneticAlign::FeatureValueMatrix[:VOWEL => "+".to_sym, :NASAL => "-".to_sym, :VOICED => "+".to_sym])
        }
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
      assert_equal("PhoneTable: 8 segments", @phones.inspect)
    end
  end

end


class WordListTestCase < Test::Unit::TestCase

  context "A Word list" do

    should "be creatable from a word list and segment table" do
      word_list = PhoneticAlign::WordList.new($words, $segments)
      transcriptions = ["dʒʌmp", "dʒʌmps", "dʒʌmpiŋ", "si", "siz", "siiŋ"]
      assert_equal(transcriptions, word_list.collect { |w| w.transcription })
      # jump is the first word in the list
      jump = word_list.first
      # Verify the semantic features of jump
      assert_equal({"LEMMA" => "jump", "PERNUM" => "non-3sg", "ASPECT" => "perfect"}, jump.meaning)
      # Verify segments on jump
      assert_equal([:dʒ, :ʌ, :m, :p], jump.phonetic_component.collect { |p| p.ipa })
      # Verify the phonetic featuers of the first segment in jump
      assert_equal({:VOWEL => :"-", :NASAL => :"-", :VOICED => :"+"}, jump.phonetic_component.first.features)
    end

    should "be creatable from a word list without a segment table" do
      word_list = PhoneticAlign::WordList.new($words)
      transcriptions = ["dʒʌmp", "dʒʌmps", "dʒʌmpiŋ", "si", "siz", "siiŋ"]
      assert_equal(transcriptions, word_list.collect { |w| w.transcription })
      djump = word_list.first
      assert_equal({"LEMMA" => "jump", "PERNUM" => "non-3sg", "ASPECT" => "perfect"}, djump.meaning)
      djump_form = "dʒʌmp".split("").collect { |f| PhoneticAlign::Phone.new(f, {}) }
      assert_equal(djump_form, djump.phonetic_component)
    end

    should "raise a RuntimeError if either of its intialization tables does not contain a FORM column" do
      no_form_data = "COL A, COL B\na,b"
      assert_raise(RuntimeError) { PhoneticAlign::WordList.new(no_form_data) }
      assert_raise(RuntimeError) { PhoneticAlign::WordList.new($words, no_form_data) }
    end

    should "raise an ArgumentError if a word contains a segment not in the segment table" do
      bad_segment_data = "FORM, LEMMA, PERNUM, ASPECT\ndʒʌXp,jump, non-3sg, perfect"
      assert_raise(ArgumentError) { PhoneticAlign::WordList.new($words, bad_segment_data) }
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
