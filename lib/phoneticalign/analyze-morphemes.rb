require "phoneticalign"

# The <em>analyze-morphemes</em> executable.
module AnalyzeMorphemes

  # The main routine for the executable <em>analyze-morphemes</em>.
  #
  # [_out_] output stream, default STDOUT
  # [_arguments_] command line arguments, default none
  def AnalyzeMorphemes.main(out = STDOUT, arguments = [])
    # The default analysis parameters.
    default_parameters = {
                            :new_morpheme_depth => 5,
                            :beam_width => 5,
                            :powerset_search_cutoff => 5
                          }
    # Get parameters from the command line and configuration files.
    parser, parameters = get_parameters(default_parameters, arguments)
    if parameters.has_key?(:logging)
      PhoneticAlign.set_log_level(eval("Logger::#{parameters[:logging]}"))
    end
    PhoneticAlign::LOGGER.debug("Parameters\n#{parameters}")

    if not parameters.has_key?(:words)
      parser.exit_error("Words file not specified")
    end

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

    # Do analysis.
    analysis = PhoneticAlign::MorphologicalAnalysis.new(word_list,
                                          parameters[:new_morpheme_depth],
                                          parameters[:powerset_search_cutoff])
    beam_search = PhoneticAlign::BeamSearch.new(parameters[:beam_width],
                                                analysis)
    i = 0
    while not beam_search.done?
      PhoneticAlign::LOGGER.info("Iteration #{i}\n#{beam_search}")
      beam_search.next_iteration!
      i += 1
    end
    out.puts beam_search
  end


  # Get parameters from the command line and configuration files.
  #
  # This returns the list [parser, parameters].  Parser is a parser object
  # which may be used by the caller to relay verbose error messages. 
  # Parameters is a hash containing information taken from the configuration
  # file and command line.  It has the folllowing keys: :logging, :words,
  # :phones.
  #
  # [<em>default_parameters</em>] default parameter hash
  # [_arguments_] command line arguments
  def AnalyzeMorphemes.get_parameters(default_parameters, arguments)
    # Create the analysis parameters object from configuration files.
    parameters = PhoneticAlign::AnalysisParameters.new(default_parameters)

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
      
      opts.on("-b", "--beam-width N", Integer, "Beam search width") do |n|
        parameters[:beam_width] = n
      end

      opts.on("-n", "--new-morpheme-depth N", Integer,
              "Number of new morpheme hypotheses to consider " +
              "for a single analysis") do |n|
        parameters[:new_morpheme_depth] = n
      end
      
      opts.on("-p", "--powerset-search-cutoff N", Integer,
              "Cutoff value for powerset search "+
              "(default #{parameters[:powerset_search_cutoff]})") do |n|
        parameters[:powerset_search_cutoff] = n
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

