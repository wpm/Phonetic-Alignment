require "optparse"


# Combinatorial extensions to Ruby's Array class.
class Array
  # Enumerate over all the subsets of this array's elements.  Enumerating over
  # all subsets yields the power set.
  #
  #    > [1,2,3].each_subset {|p| puts p.inspect}
  #    []
  #    [1]
  #    [2]
  #    [1, 2]
  #    [3]
  #    [1, 3]
  #    [2, 3]
  #    [1, 2, 3]
  #    => nil
  def each_subset # :yields: subset Array
    if empty?
      yield []
    else
      x = first
      self[1..-1].each_subset do |s|
        yield s
        yield [x] + s
      end
    end
  end

  # The powerset of this array in order from largest to smallest subset.
  def powerset_by_length
    powerset = []
    each_subset {|subset| powerset << subset}
    powerset.sort_by {|subset| -subset.length}
  end

end


# Extension of the OptionParser class with functions that automatically verify
# the input and print error messages.
class OptionParser
  # Parse the command line.  If it contains an error, print a message and exit
  # cleanly.
  #
  # This function takes an optional block that is passed this object after the
  # command line has been processed.  This may be used to verify that these
  # arguments received are correct and raise errors if they are not.
  def parse_with_error_handling!(arguments)
    begin
      parse!(arguments)
    rescue OptionParser::InvalidOption => e
      exit_error(e, 1)
    end
    yield self if block_given?
  end

  # Print and error message and exit.
  def exit_error(message, exit_code = -1)
    puts "#{message}\n\n#{help}"
    exit(exit_code)
  end
end


module PhoneticAlign

  # Parameter settings for the analysis
  #
  # These can be loaded from configuration files.  These configuration files
  # YAML hashes.  The following parameters may be specified:
  #
  # logging:: the logging level
  # words:: the words file
  # phones:: the phones file
  class AnalysisParameters < Hash
    # Create the settings object from configuration files.
    #
    # Values from files at the front of list take precedence over values from
    # files further down.  Parameters are also taken from a .phoneticalign
    # file in the home directory after any caller-specified configuration
    # files.
    #
    # [_filenames_] list configuration filenames
    def initialize(filenames = [])
      filenames += [File.join(ENV["HOME"], ".phoneticalign")]
      filenames.reverse!
      filenames.each do |filename|
        if File.file?(File.expand_path(filename))
          self.merge_config_file!(filename)
        end
      end
    end

    # A table of parameters and values sorted by parameter.
    def to_s
      longest = keys.map { |p| p.to_s.length }.max
      keys.sort {|a,b| a.to_s <=> b.to_s}.collect do |parameter|
        "#{parameter.to_s.ljust(longest)} #{self[parameter]}"
      end.join("\n")
    end

    # Merge the parameters in a configuraton file into this one.
    #
    # [_filename_] configuration YAML file name
    def merge_config_file!(filename)
      filename = File.expand_path(filename)
      self.merge!(YAML.load_file(filename))
    end

    # Merge another hash into this one, converting string parameters to
    # symbols.
    #
    # [_h_] another hash
    def merge!(h)
      h.each { |parameter, value| self[parameter.to_sym] = value }
    end

  end

end

