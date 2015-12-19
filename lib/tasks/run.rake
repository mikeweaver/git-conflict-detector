require_relative 'rake_helpers'
require_relative '../conflict_detector'

namespace :run do
  desc "run the git conflict detector"
  task :conflict_detector => :environment do |task, args|
    FileUtils.mkdir_p(GlobalSettings.cache_directory)

    GlobalSettings.repos_to_check.each do |repo_name, repo_settings|
      ConflictDetector.new(repo_settings).run
    end
  end
end




