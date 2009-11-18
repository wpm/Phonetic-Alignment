require "phoneticalign"

# The <em>analyze-morphemes</em> executable.
module AnalyzeMorphemes

  # The main routine for the executable <em>analyze-morphemes</em>.
  def AnalyzeMorphemes.main(stdout, arguments = [])
    # Get parameters from the command line and configuration files.
    parameters = get_parameters
    PhoneticAlign::LOGGER.debug("Parameters\n#{parameters}")

    parser.exit_error("Words file not specified") \
      unless parameters.has_key?(:words)

    # Open data files.
    words, segments = [:words, :segments].map do |arg|
      arg = parameters[arg]
      case arg
      when nil
        nil
      when "-"
        $stdin
      else
        open(File.expand_path(arg))
      end
    end

    word_list = PhoneticAlign::WordList.new(words, segments)
    analysis = PhoneticAlign::MorphologicalAnalysis.new(word_list)

    # Do analysis.
    alignments = analysis.align_words
    morpheme_hypotheses = analysis.best_morpheme_hypotheses(alignments)
    morpheme_hypotheses.each_key do |p|
      hyps = morpheme_hypotheses[p]
      puts hyps.first.transcription
      puts "-" * hyps.first.transcription.length
      puts hyps.join("\n")
      puts
    end
  end

  # Get parameters from the command line and configuration files.
  def AnalyzeMorphemes.get_parameters
    # Create the analysis parameters object from configuration files.
    parameters = PhoneticAlign::AnalysisParameters.new

    # Parse the command line arguments.
    config = nil
    parser = OptionParser.new do |opts|
      opts.banner =<<-EOTEXT
  #{File.basename(__FILE__)} [OPTIONS] words [segments]

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
    parser.parse_with_error_handling!

    # Incorporate options into the parameters.
    parameters.merge_config_file!(config) if not config.nil?
    if parameters.has_key?(:logging)
      PhoneticAlign.set_log_level(eval("Logger::#{parameters[:logging]}"))
    end

    # Incorporate positional arguments into the parameters.
    parameters[:words] = ARGV[0] if not ARGV[0].nil?
    parameters[:segments] = ARGV[1] if not ARGV[1].nil?

    parameters
  end
  
end

