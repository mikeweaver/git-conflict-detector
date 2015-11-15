require_relative 'rake_helpers'
require_relative '../conflict_detector'

namespace :run do
  desc "run the git conflict detector"
  task :conflict_detector, [:settings_file_path] => :environment do |task, args|
    args.with_defaults(settings_file_path: 'config/settings.yml')

    settings = YAML.load(File.read(args.settings_file_path)).symbolize_keys

    FileUtils.mkdir_p(File.dirname(settings[:log_file]))
    FileUtils.mkdir_p(settings[:cache_directory])
    settings[:email_override].downcase!
    settings[:email_filter].collect! {|email| email.downcase}

    settings[:repos_to_check].each do |repo_name, repo_settings|
      # combine the global and repo specific settings and remove other repo settings
      repo_settings = settings.merge(repo_settings)
      repo_settings.delete(:repos_to_check)
      repo_settings.symbolize_keys!

      c = ConflictDetector.new(repo_settings)
      c.run
    end
  end
end




