ENV['RAILS_ENV'] ||= 'test'
require 'coveralls'
Coveralls.wear!('rails') if ENV['CI'] == 'true'
require_relative '../config/environment'
require 'rails/test_help'
require_relative '../lib/git/git.rb'
require_relative '../lib/git/git_branch.rb'
require_relative '../lib/git/git_conflict.rb'
require_relative '../lib/git/git_commit.rb'
require_relative '../lib/git/git_error.rb'
require 'database_cleaner'
require 'rake'
require 'rspec/rails'
require 'fakefs/spec_helpers'
require 'webmock/rspec'
require 'digest/sha1'
require 'securerandom'

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

def load_json_fixture(fixture_name)
  JSON.parse(load_fixture_file("#{fixture_name}.json"))
end

def load_fixture_file(fixture_file_name)
  File.read(Rails.root.join("spec/fixtures/#{fixture_file_name}"))
end

def create_test_git_branch(repository_name: 'repository_name', name: 'path/branch', last_modified_date: Time.now, author_name: 'Author Name', author_email: 'author@email.com')
  Git::GitBranch.new(repository_name, name, last_modified_date, author_name, author_email)
end

def create_test_git_conflict(repository_name: 'repository_name', branch_a_name: 'branch_a', branch_b_name: 'branch_b', file_list: ['file1', 'file2'])
  Git::GitConflict.new(repository_name, branch_a_name, branch_b_name, file_list)
end

def create_test_git_commit(sha: '1234567890123456789012345678901234567890', message: 'Commit message', author_name: 'Author Name', author_email: 'author@email.com', commit_date: Time.now)
  Git::GitCommit.new(sha, message, commit_date, author_name, author_email)
end

def create_test_branch(repository_name: 'repository_name', name: 'path/branch', last_modified_date: Time.now, author_name: 'Author Name', author_email: 'author@email.com')
  git_data = create_test_git_branch(
      repository_name: repository_name,
      name: name,
      last_modified_date: last_modified_date,
      author_name: author_name,
      author_email: author_email)
  Branch.create_from_git_data!(git_data)
end

def create_test_branches(repository_name: 'repository_name', author_name: 'Author Name', author_email: 'author@email.com', count: 2)
  branches = []
  (0..count - 1).each do |i|
    branches << create_test_branch(
        repository_name: repository_name,
        name: "path/#{author_name}/branch#{i}",
        last_modified_date: DateTime.now,
        author_name: author_name,
        author_email: author_email)
  end
  branches
end

def create_test_commit(sha: '1234567890123456789012345678901234567890', message: 'Commit message', author_name: 'Author Name', author_email: 'author@email.com')
  commit = Commit.create(sha: sha, message: message)
  commit.author = User.first_or_create!(name: author_name, email: author_email)
  commit.save!
  commit
end

def create_test_commits(author_name: 'Author Name', author_email: 'author@email.com', count: 2)
  commits = []
  (0..count - 1).each do |i|
    commits << create_test_commit(
        sha: "#{i+1}".ljust(40, '0'),
        message: "Commit message #{i+1}",
        author_name: author_name,
        author_email: author_email)
  end
  commits
end

def create_test_conflict(branch_a, branch_b, tested_at: Time.now, file_list: ['test/file.rb'])
  Conflict.create!(branch_a, branch_b, file_list, tested_at)
end

def create_test_merge(source_branch, target_branch, successful: true)
  Merge.create!(source_branch: source_branch, target_branch: target_branch, successful: successful)
end

def create_test_push(sha: nil)
  json = load_json_fixture('github_push_payload')
  if sha
    json['after'] = sha
    json['head_commit']['id'] = sha
  end
  Push.create_from_github_data!(Github::Api::PushHookPayload.new(json))
end

def create_test_jira_issue_json(key: nil, status: nil, targeted_deploy_date: Time.now.tomorrow)
  json = load_json_fixture('jira_issue_response').clone
  if key
    json['key'] = key
  end
  if status
    json['fields']['status']['name'] = status
  end
  if targeted_deploy_date
    json['fields']['customfield_10600'] = targeted_deploy_date.to_time.iso8601
  else
    json['fields'].except!('customfield_10600')
  end
  json
end

def create_test_jira_issue(key: nil, status: nil, targeted_deploy_date: Time.now.tomorrow)
  JiraIssue.create_from_jira_data!(
      JIRA::Resource::IssueFactory.new(nil).build(
          create_test_jira_issue_json(key: key, status: status, targeted_deploy_date: targeted_deploy_date)))
end

def create_test_sha
  Digest::SHA1.hexdigest(SecureRandom.hex)
end
