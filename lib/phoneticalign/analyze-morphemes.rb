require "phoneticalign"


def main(stdout, arguments = [])
  # Parse the command line arguments.
  OptionParser.new do |opts|
    opts.banner =<<-EOTEXT
#{File.basename(__FILE__)} [OPTIONS] words [segments]

Automatically discover segmentation hypotheses.
EOTEXT

    opts.on("-l", "--logging LEVEL", "Logging level") do |level|
      PhoneticAlign.set_log_level(eval("Logger::#{level.upcase}"))
    end
  end.parse_with_error_handling! do |parser|
    if not (ARGV.length == 1 or ARGV.length == 2)
      parser.exit_error("Incorrect number of arguments", 1)
    end
  end

  # Open the input files.
  words, segments = ARGV.map do |arg|
    case arg
    when nil
      nil
    when "-"
      $stdin
    else
      open(arg)
    end
  end

  word_list = PhoneticAlign::WordList.new(words, segments)
  puts word_list
end

