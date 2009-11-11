require "optparse"


# Extension of the OptionParser class with functions that automatically verify
# the input and print error messages.
class OptionParser
  # Parse the command line.  If it contains an error, print a message and exit
  # cleanly.
  #
  # This function takes an optional block that is passed this object after the
  # command line has been processed.  This may be used to verify that these
  # arguments received are correct and raise errors if they are not.
  def parse_with_error_handling!
    begin
      parse!
    rescue OptionParser::InvalidOption => e
      exit_error(e, 1)
    end
    yield self if block_given?
  end

  # Print and error message and exit.
  def exit_error(message, exit_code)
    puts "#{message}\n\n#{help}"
    exit(exit_code)
  end
end
