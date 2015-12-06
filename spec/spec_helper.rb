ENV['RAILS_ENV'] ||= 'test'
require 'coveralls'
Coveralls.wear!('rails')
require_relative '../config/environment'
require 'rails/test_help'
require_relative '../lib/git/git.rb'
require_relative '../lib/git/git_branch.rb'
require_relative '../lib/git/git_conflict.rb'
require_relative '../lib/git/git_error.rb'
require 'database_cleaner'
require 'rake'

GitConflictDetector::Application.load_tasks

RSpec.configure do |config|

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    Rake::Task['db:test:prepare'].invoke
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

end
