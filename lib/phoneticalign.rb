$KCODE="u"
require "jcode"
require "logger"

require "phoneticalign/analysis"
require "phoneticalign/data"
require "phoneticalign/model"
require "phoneticalign/utilities"


module PhoneticAlign
  VERSION = "1.0.0"

  # If there is no meaning intersection in a set of morpheme hypotheses, we
  # can look for semantic equivalence classes by exhaustively searching
  # through the powersets.  Since this is an exponential algorithm, only do it
  # for sets equal to or smaller than this cutoff.
  POWERSET_SEARCH_CUTOFF = 8

  # Create the logger and set its default log level to ERROR.  This function
  # is called when the module is loaded.
  def PhoneticAlign.initialize_logger
    logger = Logger.new(STDERR)
    logger.level = Logger::ERROR
    logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    logger
  end

  private_class_method :initialize_logger

  # Logger used by all objects in this module.  This is initialized at module
  # load time.  The default log level is ERROR.
  LOGGER = initialize_logger

  # Set the logging level.
  #
  # [_level_] a constant from the
  #           Logger[http://www.ruby-doc.org/stdlib/libdoc/logger/rdoc]
  #           module.
  #
  #   > PhoneticAlign.set_log_level(Logger::DEBUG)
  def PhoneticAlign.set_log_level(level)
    PhoneticAlign::LOGGER.level = level
  end

end
