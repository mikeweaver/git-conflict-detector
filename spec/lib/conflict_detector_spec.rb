require 'spec_helper'

describe 'ConflictDetector' do

  def create_test_git_branches
    test_branches = []
    (0..2).each do |i|
      test_branches << create_test_git_branch(name: "path/branch#{i}")
    end
    test_branches
  end

  before do
    @settings = OpenStruct.new(DEFAULT_CONFLICT_DETECTION_SETTINGS)
    @settings.repository_name = 'repository_name'
    @settings.default_branch_name = 'master'
  end

  it 'works' do
    start_time = Time.now
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:get_branch_list) { create_test_git_branches }
    conflict_detector = ConflictDetector.new(@settings)
    expect(conflict_detector).to receive(:get_conflicts ).exactly(3).times.and_return(
      [create_test_git_conflict(branch_a_name: 'path/branch0', branch_b_name: 'path/branch1')], [], [])
    # a single notification email should be sent
    expect(ConflictsMailer).to receive(:maybe_send_conflict_email_to_user).and_call_original

    # run the test
    conflict_detector.run

    # a single conflict should be found
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.branch_a.name).to eq('path/branch0')
    expect(Conflict.first.branch_b.name).to eq('path/branch1')
    expect(Conflict.first.resolved).to be_falsey

    # branches should be created and marked as tested
    expect(Branch.all.size).to eq(3)
    expect(Branch.first.git_tested_at).to be > start_time
    expect(Branch.second.git_tested_at).to be > start_time
    expect(Branch.last.git_tested_at).to be > start_time
  end

  context 'get_conflicts' do
    def expect_get_conflicts_equals(
        unfiltered_conflict_list,
        expected_conflict_list,
        expected_push_count: 0,
        target_branch_name: 'branch_a',
        source_branch_names: ['branch_b', 'branch_c'])
      target_branch = create_test_branch(name: target_branch_name)
      source_branches = source_branch_names.collect { |branch_name| create_test_branch(name: branch_name) }
      conflict_detector = ConflictDetector.new(@settings)
      expect_any_instance_of(Git::Git).to receive(:checkout_branch)
      if unfiltered_conflict_list.size > 0
        allow_any_instance_of(Git::Git).to receive(:detect_conflicts).and_return(*unfiltered_conflict_list)
      else
        allow_any_instance_of(Git::Git).to receive(:detect_conflicts).and_return(nil)
      end
      if expected_push_count > 0
        expect_any_instance_of(Git::Git).to receive(:push).exactly(expected_push_count).times.and_return(true)
      else
        expect_any_instance_of(Git::Git).not_to receive(:push)
      end
      expect(conflict_detector.send(:get_conflicts, target_branch, source_branches)).to match_array(expected_conflict_list)
      if expected_push_count > 0
        expect(Merge.count).to eq(expected_push_count)
      else
        expect(Merge.count).to eq(0)
      end
    end

    it 'should include all conflicts when the "ignore files" list is empty' do
      @settings.ignore_conflicts_in_file_paths = []
      conflict_list = [create_test_git_conflict, nil]
      expected_conflict_list = [conflict_list[0]]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list)
    end

    it 'should ignore conflicts when all the conflicting files are on the ignore list' do
      @settings.ignore_conflicts_in_file_paths = ['ignore_me', 'regex/.*']
      conflict_list = [
          create_test_git_conflict(file_list: ['ignore_me', 'regex/match']),
          create_test_git_conflict(file_list: ['nomatch'])]
      expected_conflict_list = [conflict_list[1]]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list)
    end

    it 'should ignore all conflicts when too many branches have been checked' do
      allow(GlobalSettings).to receive(:maximum_branches_to_check).and_return(1)
      conflict_list = [create_test_git_conflict, create_test_git_conflict]
      expected_conflict_list = [create_test_git_conflict]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list)
    end

    it 'should ignore branches with the same name' do
      expect_get_conflicts_equals([], [], source_branch_names: ['branch_a'])
    end
  end
end
