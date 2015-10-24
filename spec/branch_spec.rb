require_relative '../environment'
require_relative '../models/branch.rb'
require_relative '../lib/git.rb'
require 'database_cleaner'

RSpec.configure do |config|

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

end

describe 'Branch' do

  it 'can create be constructed from git data' do
    updated_at = DateTime.now
    git_data = Git::Branch.new(
        'mypath/mybranch',
        updated_at,
        'author@email.com')
    branch = Branch.create_branch_from_git_data(git_data)

    expect(branch.name).to eq('mypath/mybranch')
    expect(branch.git_updated_at).to eq(updated_at)
    expect(branch.git_tested_at).to be_nil
    expect(branch.created_at).not_to be_nil
    expect(branch.updated_at).not_to be_nil
  end

  context 'with two existing branches' do
    before do
      (0..1).each do |i|
        git_data = Git::Branch.new(
            "path/branch#{i}",
            DateTime.now,
            'author@email.com')
        Branch.create_branch_from_git_data(git_data)
      end
    end

    it 'returns branches_not_updated_since' do
      expect(Branch.branches_not_updated_since(10.minutes.from_now).size).to eq(2)
      expect(Branch.branches_not_updated_since(10.minutes.ago).size).to eq(0)
    end

    it 'returns untested_branches' do
      expect(Branch.untested_branches.size).to eq(2)
    end
  end

  context 'with an existing branch' do

    before do
      git_data = Git::Branch.new(
          'mypath/mybranch',
          DateTime.now,
          'author@email.com')
      @branch = Branch.create_branch_from_git_data(git_data)
    end

    it 'prints its name when stringified' do
      expect(@branch.to_s).to eq('mypath/mybranch')
    end

    it 'can be compared with a regular expression' do
      expect(@branch =~ /mypath.*/).to be_truthy
      expect(@branch =~ /notmypath.*/).to be_falsey
    end
  end

end

