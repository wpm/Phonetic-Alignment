require "structuredtext"

module PhoneticAlign

  # A reader for data files listing form-feature pairs
  #
  # This reads a comma-separated value file.  The first line is a set of
  # column labels.  One of these labels must be FORM.  This column specifies
  # the form.  All other columns specify the feature values.
  #
  # Comments are delimited by #.  Blank lines are ignored.
  class FormFeatureReader < StructuredText::LabeledDelimitedReader
    @@form = "FORM"

    # Create a form-feature file from text data.
    #
    # [_data_] the form-feature data; this is an enumeration of strings
    def initialize(form_feature_data)
      super(StructuredText::CommentedReader.new(form_feature_data))
    end

    # Enumerate the lines of the form-feature data yielding the forms and
    # feature hashes for each line.
    def each
      super do |fields|
        form = fields.delete(@@form)
        raise "Missing #{@@form} value" if form.nil?
        # Values missing from the final field in a row will be returned as
        # nil.  Map them to empty string.
        fields.each { |f,v| fields[f] = "" if v.nil? }
        # Features with empty values are unspecified: remove them.
        fields.delete_if { |f,v| v.empty? }
        yield [form, fields]
      end
    end
  end


  # A table of phones indexed by IPA character.
  #
  # IPA characters, features, and values are all stored as Ruby symbols.
  class PhoneTable < Hash
    # Create the table from comma-separated value data.
    #
    # [<em>phone_data</em>] phone table CSV string
    #
    # Feature and value strings in the CSV file are converted to symbols.
    def initialize(phone_data = "")
      FormFeatureReader.new(phone_data).each do |form, raw_features|
        # Convert strings to symbols.
        features = {}
        raw_features.each {|f,v| features[f.to_sym] = v.to_sym}
        self[form] = Phone.new(form.to_sym, FeatureValueMatrix.from_hash(features))
      end
      # Create a regular expression used in phonological_sequence.  The IPA
      # keys are sorted by length so that multi-character phones are matched
      # first.  The '.' at the end matches phones not listed in the table,
      # which will cause phone_sequence to raise an ArgumentError.
      segs = keys.sort_by {|s| -s.jlength} + ['.']
      @seg_regex = Regexp.compile(segs.join("|"))
    end

    # The phone table sorted by IPA character.
    def to_s
      # Set the width of the IPA column equal to the longest graph.
      longest = values.map { |p| p.ipa.to_s.jlength }.max
      values.sort_by  { |p| p.ipa.to_s }.map do |p|
        p.to_s(longest)
      end.join("\n")
    end

    # The class name and the number of phones in the table.
    def inspect
      "PhoneTable: #{length} phones"
    end

    # Parse a phonological transcription string into a sequence of strings
    # that match the phones listed in this table.
    #
    # [_s_] A phonological transcription string
    def phone_sequence(s)
      phones = []
      s.scan(@seg_regex) do |seg|
        begin
          phones << fetch(seg)
        rescue IndexError
          raise ArgumentError.new("/#{seg}/ in #{s} "+
                                  "is not in the phone table")
        end
      end
      phones
    end

  end


  # A list of words.
  class WordList < Array

    # Create the word list from comma-separated value data.
    #
    # [<em>word_data</em>] word list CSV string
    # [<em>phone_data</em>] optional phone table CSV string
    def initialize(word_data, phone_data = nil)
      # Initialize the phone table if phone data is specified.
      phone_table = PhoneTable.new(phone_data.nil? ? "" : phone_data)
      # Initialize the word list from the the specified data.
      FormFeatureReader.new(word_data).each do |form_s, features|
        phones = if phone_table.empty?
          # Create a featureless phone for each character in form_s.
          form_s.split("").collect { |s| Phone.new(s) }
        else
          # Look up the characters in form_s in the phone table.
          phone_table.phone_sequence(form_s)
        end
        self << Word.new(phones, FeatureValueMatrix.from_hash(features))
      end
    end

    # Print the word transcriptions and their semantic feature matrixes.
    def to_s
      join("\n")
    end

  end # WordList


end