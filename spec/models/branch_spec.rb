require 'spec_helper'

describe 'Branch' do

  it 'can create be constructed from git data' do
    branch = create_test_branch
    expect(branch.name).to eq('path/branch')
    expect(branch.git_updated_at).to_not be_nil
    expect(branch.git_tested_at).to be_nil
    expect(branch.created_at).not_to be_nil
    expect(branch.updated_at).not_to be_nil
  end

  it 'does not create duplicate database records' do
    git_data = Git::GitBranch.new('repository_name', 'name', Time.now, 'author_name', 'author@email.com')
    Branch.create_from_git_data!(git_data)
    expect(Branch.all.count).to eq(1)

    Branch.create_from_git_data!(git_data)
    expect(Branch.all.count).to eq(1)
  end

  it 'distinguishes between branches in different repositories' do
    git_data_a = Git::GitBranch.new('repository_name', 'name', Time.now, 'author_name', 'author@email.com')
    Branch.create_from_git_data!(git_data_a)
    expect(Branch.all.count).to eq(1)

    git_data_b = Git::GitBranch.new('other_repository_name', 'name', Time.now, 'author_name', 'author@email.com')
    Branch.create_from_git_data!(git_data_b)
    expect(Branch.all.count).to eq(2)
  end

  it 'can be sorted alphabetically by name' do
    names = ['b', 'd', 'a', 'c']
    (0..3).each do |i|
      git_data = create_test_branch(name: names[i])
    end
    # ensure they came out of the DB in the same order we put them in
    expect(Branch.first.name).to eq('b')

    # sort the names and the branches, they should match
    names.sort.zip(Branch.all.sort).each do |name, branch|
      expect(branch.name).to eq(name)
    end
  end

  context 'with two existing branches' do
    before do
      (0..1).each do |i|
        create_test_branch(name: "path/branch#{i}")
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

  it 'returns branches from a repository' do
    create_test_branch(repository_name: 'repository_a', name: 'name_a')
    create_test_branch(repository_name: 'repository_b', name: 'name_b')

    branches_a = Branch.from_repository('repository_a').all
    expect(branches_a.size).to eq(1)
    expect(branches_a[0].name).to eq('name_a')
  end

  context 'with an existing branch' do

    before do
      @branch = create_test_branch
    end

    it 'prints its name when stringified' do
      expect(@branch.to_s).to eq('path/branch')
    end

    it 'can be compared with a regular expression' do
      expect(@branch =~ /path.*/).to be_truthy
      expect(@branch =~ /notmypath.*/).to be_falsey
    end

    it 'can be marked as tested' do
      expect(@branch.git_tested_at).to be_nil
      current_time = Time.now + 1000
      Timecop.freeze(current_time) do
        @branch.mark_as_tested!
        @branch.reload
        expect(@branch.git_tested_at.to_i).to eq(current_time.to_i)
      end

      current_time = Time.now + 2000
      Timecop.freeze(current_time) do
        @branch.mark_as_tested!
        @branch.reload
        expect(@branch.git_tested_at.to_i).to eq(current_time.to_i)
      end
    end
  end

end

