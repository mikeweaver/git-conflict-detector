require_relative 'rake_helpers'
require_relative '../conflict_detector'

namespace :run do
  desc "run the git conflict detector"
  task :conflict_detector => :environment do |task, args|
    GlobalSettings.repositories_to_check_for_conflicts.each do |repository_name, settings|
      ConflictDetector.new(settings).run
    end
  end
end




