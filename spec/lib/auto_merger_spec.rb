require 'spec_helper'

describe 'AutoMerger' do

  def create_test_git_branches(target_branch_count)
    test_branches = []
    (0..(target_branch_count - 1)).each do |i|
      test_branches << create_test_git_branch(name: "target/branch#{i}")
    end
    test_branches << create_test_git_branch(name: 'master')
    test_branches << create_test_git_branch(name: 'source')
    test_branches
  end

  before do
    @settings = OpenStruct.new(DEFAULT_AUTO_MERGE_SETTINGS)
    @settings.repository_name = 'repository_name'
    @settings.default_branch_name = 'master'
    @settings.source_branch_name = 'source'
    @settings.only_branches = ['target/.*']
  end

  def expect_merges(target_branch_count: 0, conflict_count: 0, branches_up_to_date: false)
    raise 'Conflict count must be <= target branch count' if conflict_count > target_branch_count
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:get_branch_list) { create_test_git_branches(target_branch_count) }
    expect_any_instance_of(Git::Git).to receive(:push).exactly(target_branch_count - conflict_count).times.and_return(!branches_up_to_date)
    expect_any_instance_of(Git::Git).to receive(:checkout_branch).exactly(target_branch_count).times
    conflict_results = []
    (0..(conflict_count - 1)).each do |i|
      conflict_results << create_test_git_conflict(branch_a_name: 'source', branch_b_name: 'target/branch0')
    end
    (0..(target_branch_count - 1 - conflict_count)).each do |i|
      conflict_results << nil
    end
    expect_any_instance_of(Git::Git).to receive(:detect_conflicts).exactly(target_branch_count).times.and_return(*conflict_results)
    auto_merger = AutoMerger.new(@settings)


    # run the test
    auto_merger.run

    # merges should be created for non conflicting and non-up to date branches
    if branches_up_to_date
      expect(Merge.all.size).to eq(0)
    else
      expect(Merge.all.size).to eq(target_branch_count - conflict_count)
      Merge.all.each do |merge|
        expect(merge.target_branch.name).to match(/target\/.*/)
        expect(merge.source_branch.name).to eq('source')
      end
    end

    # branches should be created and marked as untested
    expect(Branch.all.size).to eq(target_branch_count + 2)
    Branch.all.each do |branch|
      expect(branch.git_tested_at).to be_nil
    end
  end

  it 'merges the target branches' do
    expect_merges(target_branch_count: 2)
  end

  it 'does not try to merge the source branch with itself' do
    @settings.only_branches = ['target/.*', 'source']
    expect_merges(target_branch_count: 2)
  end

  it 'does not push conflicting branches' do
    expect_merges(target_branch_count: 2, conflict_count: 1)
  end

  it 'does not push branches that are already up to date' do
    expect_merges(target_branch_count: 2, branches_up_to_date: true)
  end

end
