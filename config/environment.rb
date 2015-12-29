# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# log to stdout and file
Rails.logger.extend(ActiveSupport::Logger.broadcast(Logger.new(STDOUT)))
