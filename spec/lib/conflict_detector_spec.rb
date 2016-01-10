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
    expect_any_instance_of(Git::Git).to receive(:diff_branch_with_ancestor).exactly(2).times.and_return(['file1', 'file2'])
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
        target_branch_name: 'branch_a',
        source_branch_names: ['branch_b', 'branch_c'],
        alreadyUpToDate: false)
      target_branch = create_test_branch(name: target_branch_name)
      source_branches = source_branch_names.collect { |branch_name| create_test_branch(name: branch_name) }
      conflict_detector = ConflictDetector.new(@settings)
      expect_any_instance_of(Git::Git).to receive(:checkout_branch)
      if unfiltered_conflict_list.size > 0
        return_values = unfiltered_conflict_list.collect { |conflict| [false, conflict] }
        allow_any_instance_of(Git::Git).to receive(:merge_branches).and_return(*return_values)
      else
        allow_any_instance_of(Git::Git).to receive(:merge_branches).and_return([!alreadyUpToDate, nil])
      end
      expect(conflict_detector.send(:get_conflicts, target_branch, source_branches)).to match_array(expected_conflict_list)
    end

    it 'should include all conflicts found' do
      conflict_list = [create_test_git_conflict, nil, create_test_git_conflict(branch_b_name: 'branch_d')]
      expected_conflict_list = [conflict_list[0], conflict_list[2]]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list, source_branch_names: ['branch_b', 'branch_c', 'branch_d'])
    end

    it 'should not treat branches that do not need merging as conflicts' do
      expect_get_conflicts_equals([], [], alreadyUpToDate: true)
    end

    it 'should ignore all conflicts when too many branches have been checked' do
      allow(GlobalSettings).to receive(:maximum_branches_to_check).and_return(1)
      conflict_list = [create_test_git_conflict, create_test_git_conflict(branch_b_name: 'branch_c')]
      expected_conflict_list = [conflict_list[0]]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list)
    end

    it 'should ignore branches with the same name' do
      expect_get_conflicts_equals([], [], source_branch_names: ['branch_a'])
    end
  end

  context 'get_conflicting_files_to_ignore' do
    before do
      allow_any_instance_of(Git::Git).to receive(:diff_branch_with_ancestor).and_return(
                                             ['not_inherited_file_1', 'not_inherited_file_2'], ['not_inherited_file_3'])
    end

    def expect_get_conflicting_files_to_ignore_equals(conflict, expected_file_list)
      conflict_detector = ConflictDetector.new(@settings)
      expect(conflict_detector.send(:get_conflicting_files_to_ignore, conflict)).to match_array(expected_file_list)
    end

    it 'should be empty when the "ignore files" list is empty and there are no inherited conflicting files' do
      @settings.ignore_conflicts_in_file_paths = []
      expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['not_inherited_file_1', 'not_inherited_file_2', 'not_inherited_file_3']),
          [])
    end

    it 'should contain the conflicting files on the "ignore files" list' do
      @settings.ignore_conflicts_in_file_paths = ['not_inherited_file_1']
      expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['not_inherited_file_1', 'not_inherited_file_2', 'not_inherited_file_3']),
          ['not_inherited_file_1'])
      expect_get_conflicting_files_to_ignore_equals(create_test_git_conflict(file_list: ['not_inherited_file_2']), [])
    end

    it 'should contain inherited conflicting files if present' do
      @settings.ignore_conflicts_in_file_paths = []
      expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['inherited_file_1', 'not_inherited_file_1', 'not_inherited_file_3']),
          ['inherited_file_1'])
    end

    it 'should contain inherited conflicting files and ignored files if both are present' do
      @settings.ignore_conflicts_in_file_paths = ['not_inherited_file_1']
      expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['inherited_file_1', 'not_inherited_file_1', 'not_inherited_file_3']),
          ['inherited_file_1', 'not_inherited_file_1'])
    end
  end
end
