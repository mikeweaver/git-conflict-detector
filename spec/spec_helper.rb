ENV['RAILS_ENV'] ||= 'test'
require 'coveralls'
Coveralls.wear!('rails') if ENV['CI'] == 'true'
require_relative '../config/environment'
require 'rails/test_help'
require 'git/git_test_helpers'
require 'git_models/test_helpers'
require 'database_cleaner'
require 'rake'
require 'rspec/rails'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'digest/sha1'
require 'securerandom'

GitConflictDetector::Application.load_tasks

RSpec.configure do |config|
  config.include StubEnv::Helpers

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    Rake::Task['db:test:prepare'].invoke
  end

  config.around(:each) do |example|
    # reload settings each time in case the tests are mutating them
    Object.send(:remove_const, :GlobalSettings)
    GlobalSettings = load_global_settings
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

def create_test_conflict(branch_a, branch_b, tested_at: Time.current, file_list: ['test/file.rb'])
  Conflict.create!(branch_a, branch_b, file_list, tested_at)
end

def create_test_merge(source_branch, target_branch, successful: true)
  Merge.create!(source_branch: source_branch, target_branch: target_branch, successful: successful)
end
