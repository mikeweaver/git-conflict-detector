require 'spec_helper'

describe 'ConflictDetector' do

  def create_test_git_branches
    test_branches = []
    (0..2).each do |i|
      test_branches << Git::GitBranch.new(
          'repository_name',
          "path/branch#{i}",
          DateTime.now,
          'Author Name',
          'author@email.com')
    end
    test_branches
  end

  it 'works' do
    start_time = Time.now
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    conflict_detector = ConflictDetector.new(GlobalSettings.repositories_to_check['MyRepo'])
    expect(conflict_detector).to receive(:get_branch_list) { create_test_git_branches }
    expect(conflict_detector).to receive(:get_conflicts ).exactly(3).times.and_return(
      [Git::GitConflict.new('repository_name', 'path/branch0', 'path/branch1', ['dir/file.rb'])], [], [])
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

  context 'get_branch_list' do
    before do
      @settings = OpenStruct.new(DEFAULT_REPOSITORY_SETTINGS)
      @settings.repository_name = 'MyRepo'
      @settings.master_branch_name = 'master'
    end

    def expect_get_branch_list_equals(unfiltered_branch_list, expected_branch_list)
      conflict_detector = ConflictDetector.new(@settings)
      expect_any_instance_of(Git::Git).to receive(:get_branch_list).and_return(unfiltered_branch_list)
      expect(conflict_detector.send(:get_branch_list)).to match_array(expected_branch_list)
    end

    it 'should include all branches when the "ignore branch" list is empty' do
      @settings.ignore_branches = []
      branch_list = [create_test_git_branch(name:'straight_match')]
      expect_get_branch_list_equals(branch_list, branch_list)
    end

    it 'should ignore branches on the list when the "ignore branch" list is NOT empty' do
      @settings.ignore_branches = ['straight_match', 'regex/.*']
      unfiltered_branch_list = [
          create_test_git_branch(name:'straight_match'),
          create_test_git_branch(name:'regex/match'),
          create_test_git_branch(name:'no_match')]
      expected_branch_list = [unfiltered_branch_list[2]]
      expect_get_branch_list_equals(unfiltered_branch_list, expected_branch_list)
    end

    it 'should include all branches when the "only branch" list is empty' do
      @settings.only_branches = []
      branch_list = [create_test_git_branch(name:'straight_match')]
      expect_get_branch_list_equals(branch_list, branch_list)
    end

    it 'should include branches on the list when the "only branch" list is NOT empty' do
      @settings.only_branches = ['straight_match', 'regex/.*']
      unfiltered_branch_list = [
          create_test_git_branch(name:'straight_match'),
          create_test_git_branch(name:'regex/match'),
          create_test_git_branch(name:'no_match')]
      expected_branch_list = [unfiltered_branch_list[0], unfiltered_branch_list[1]]
      expect_get_branch_list_equals(unfiltered_branch_list, expected_branch_list)
    end

    it 'should include all branches when the "modified days ago" is zero' do
      @settings.ignore_branches_modified_days_ago = 0
      branch_list = [create_test_git_branch(name:'straight_match')]
      expect_get_branch_list_equals(branch_list, branch_list)
    end

    it 'should include new branches when the "modified days ago" is > 0' do
      @settings.ignore_branches_modified_days_ago = 1
      unfiltered_branch_list = [
          create_test_git_branch(name:'old', last_modified_date: 2.days.ago),
          create_test_git_branch(name:'new', last_modified_date: 1.minute.from_now)]
      expected_branch_list = [unfiltered_branch_list[1]]
      expect_get_branch_list_equals(unfiltered_branch_list, expected_branch_list)
    end
  end

  context 'get_conflicts' do
    before do
      @settings = OpenStruct.new(DEFAULT_REPOSITORY_SETTINGS)
      @settings.repository_name = 'MyRepo'
      @settings.master_branch_name = 'master'
    end

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

    it 'should push the merged branch when requested' do
      @settings.push_successful_merges_of['branch_b'] = ['branch_a']
      expect_get_conflicts_equals([], [], target_branch_name: 'branch_a', source_branch_names: ['branch_b'], expected_push_count: 1)
    end
  end
end
