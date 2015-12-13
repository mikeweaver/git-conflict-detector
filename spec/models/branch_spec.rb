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

  it 'can be sorted alphabetically by name' do
    names = ['b', 'd', 'a', 'c']
    (0..3).each do |i|
      git_data = create_test_branch(name=names[i])
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
        create_test_branch(name="path/branch#{i}")
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

