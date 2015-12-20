require_relative 'rake_helpers'
require_relative '../conflict_detector'

namespace :run do
  desc "run the git conflict detector"
  task :conflict_detector => :environment do |task, args|
    FileUtils.mkdir_p(GlobalSettings.cache_directory)

    GlobalSettings.repositories_to_check.each do |repository_name, settings|
      ConflictDetector.new(settings).run
    end
  end
end




