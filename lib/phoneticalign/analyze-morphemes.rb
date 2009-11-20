require "phoneticalign"

# The <em>analyze-morphemes</em> executable.
module AnalyzeMorphemes

  # The main routine for the executable <em>analyze-morphemes</em>.
  def AnalyzeMorphemes.main(stdout = STDOUT, arguments = [])
    # Get parameters from the command line and configuration files.
    parser, parameters = get_parameters(arguments)
    if parameters.has_key?(:logging)
      PhoneticAlign.set_log_level(eval("Logger::#{parameters[:logging]}"))
    end
    PhoneticAlign::LOGGER.debug("Parameters\n#{parameters}")

    parser.exit_error("Words file not specified") \
      unless parameters.has_key?(:words)

    # Open data files.
    words, phones = [:words, :phones].map do |arg|
      arg = parameters[arg]
      case arg
      when nil
        nil
      when "-"
        STDIN
      else
        open(File.expand_path(arg))
      end
    end

    word_list = PhoneticAlign::WordList.new(words, phones)
    analysis = PhoneticAlign::MorphologicalAnalysis.new(word_list)

    # Do analysis.
    alignments = analysis.align_words
    stdout.puts analysis.best_morpheme_hypotheses(alignments)
    # puts morpheme_hypotheses.sort_by {|h| h.match_rate}.join("\n\n")
    # phonetic_equivalence_class = analysis.best_morpheme_hypotheses(alignments)
    # lines = phonetic_equivalence_class.collect do |p, hyps|
    #   p.to_s + "\n" +
    #   "-" * p.to_s.length + "\n" +
    #   hyps.join("\n")
    # end
    # puts lines.join("\n\n")
  end


  # Get parameters from the command line and configuration files.
  #
  # This returns the list [parser, parameters].  Parser is a parser object
  # which may be used by the caller to relay verbose error messages. 
  # Parameters is a hash containing information taken from the configuration
  # file and command line.  It has the folllowing keys: :logging, :words,
  # :phones.
  #
  # [_arguments_] command line arguments
  def AnalyzeMorphemes.get_parameters(arguments)
    # Create the analysis parameters object from configuration files.
    parameters = PhoneticAlign::AnalysisParameters.new

    # Parse the command line arguments.
    config = nil
    parser = OptionParser.new do |opts|
      opts.banner =<<-EOTEXT
#{File.basename(__FILE__)} [OPTIONS] words [phones]

Automatically discover segmentation hypotheses.

Parameters may be specified in a YAML file called .phoneticalign in your home
directory.
EOTEXT

      opts.on("-l", "--logging LEVEL", "Logging level") do |level|
        parameters[:logging] = level.upcase
      end

      opts.on("-c", "--config FILE", "YAML config file") do |filename|
        config = filename
      end
    end
    parser.parse_with_error_handling!(arguments)

    # Incorporate options into the parameters.
    parameters.merge_config_file!(config) if not config.nil?

    # Incorporate positional arguments into the parameters.
    parameters[:words] = arguments[0] if not arguments[0].nil?
    parameters[:phones] = arguments[1] if not arguments[1].nil?

    [parser, parameters]
  end
  
end

