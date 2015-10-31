require_relative 'rake_helpers'
require_relative '../conflict_detector'

namespace :run do
  desc "run the git conflict detector"
  task conflict_detector: :environment do |task, args|
    c = ConflictDetector.new()
    c.run()
  end
end




