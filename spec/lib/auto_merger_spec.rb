require 'spec_helper'

describe 'AutoMerger' do
  def create_test_git_branches(target_branch_count)
    test_branches = []
    (0..(target_branch_count - 1)).each do |i|
      test_branches << Git::TestHelpers.create_branch(name: "target/branch#{i}")
    end
    test_branches << Git::TestHelpers.create_branch(name: 'master')
    test_branches << Git::TestHelpers.create_branch(name: 'source')
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
    expect_any_instance_of(Git::Git).to receive(:branch_list) { create_test_git_branches(target_branch_count) }
    if branches_up_to_date
      expect_any_instance_of(Git::Git).not_to receive(:push)
    else
      expect_any_instance_of(Git::Git).to \
        receive(:push).exactly(target_branch_count - conflict_count).times.and_return(true)
      if conflict_count > 0
        expect_any_instance_of(Git::Git).to receive(:reset).exactly(conflict_count).times
      end
    end
    conflict_results = []
    (0..(conflict_count - 1)).each do
      conflict_results << [
        false,
        Git::TestHelpers.create_conflict(branch_a_name: 'source', branch_b_name: 'target/branch0')
      ]
    end
    (0..(target_branch_count - 1 - conflict_count)).each do
      conflict_results << [!branches_up_to_date, nil]
    end
    expect_any_instance_of(Git::Git).to \
      receive(:merge_branches).exactly(target_branch_count).times.and_return(*conflict_results)
    auto_merger = AutoMerger.new(@settings)
    # a single notification email should be sent
    expect(MergeMailer).to receive(:maybe_send_merge_email_to_user).and_call_original

    # run the test
    auto_merger.run

    # merges should be created for non-up to date branches
    if branches_up_to_date
      expect(Merge.all.size).to eq(0)
    else
      # check for successful and unsuccessful merges
      expect(Merge.all.size).to eq(target_branch_count)
      expect(Merge.successful.all.size).to eq(target_branch_count - conflict_count)
      Merge.successful.all.each do |merge|
        expect(merge.target_branch.name).to match(/target\/.*/)
        expect(merge.source_branch.name).to eq('source')
        expect(merge.successful).to be_truthy
      end
      expect(Merge.unsuccessful.all.size).to eq(conflict_count)
      Merge.unsuccessful.all.each do |merge|
        expect(merge.target_branch.name).to match(/target\/.*/)
        expect(merge.source_branch.name).to eq('source')
        expect(merge.successful).to be_falsey
      end
    end

    # branches should be created and marked as untested
    expect(Branch.all.size).to eq(target_branch_count + 2)
    Branch.all.each do |branch|
      expect(branch.git_tested_at).to be_nil
    end
  end

  it 'merges the source branch into the target branches' do
    expect_merges(target_branch_count: 2)
  end

  it 'merges the source tag into the target branches' do
    @settings.only_merge_source_branch_with_tag = 'master-clean-*'
    expect_any_instance_of(Git::Git).to receive(:lookup_tag).and_return('master-clean-1234')
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
