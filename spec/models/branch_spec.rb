require 'spec_helper'

describe 'Branch' do
  it 'can create be constructed from git data' do
    branch = GitModels::TestHelpers.create_branch
    expect(branch.name).to eq('path/branch')
    expect(branch.git_updated_at).not_to be_nil
    expect(branch.git_tested_at).to be_nil
    expect(branch.created_at).not_to be_nil
    expect(branch.updated_at).not_to be_nil
  end

  context 'with two existing branches' do
    before do
      (0..1).each do |i|
        GitModels::TestHelpers.create_branch(name: "path/branch#{i}")
      end
    end

    it 'returns untested_branches' do
      expect(Branch.untested_branches.size).to eq(2)
    end
  end

  context 'with an existing branch' do
    before do
      @branch = GitModels::TestHelpers.create_branch
    end

    it 'can be marked as tested' do
      expect(@branch.git_tested_at).to be_nil
      current_time = Time.current + 1000
      Timecop.freeze(current_time) do
        @branch.mark_as_tested!
        @branch.reload
        expect(@branch.git_tested_at.to_i).to eq(current_time.to_i)
      end

      current_time = Time.current + 2000
      Timecop.freeze(current_time) do
        @branch.mark_as_tested!
        @branch.reload
        expect(@branch.git_tested_at.to_i).to eq(current_time.to_i)
      end
    end
  end
end
