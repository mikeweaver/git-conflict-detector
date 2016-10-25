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
    start_time = Time.current
    expect_any_instance_of(Git::Git).to receive(:clone_repository)
    expect_any_instance_of(Git::Git).to receive(:branch_list) { create_test_git_branches }
    expect_any_instance_of(Git::Git).to \
      receive(:file_diff_branch_with_ancestor).exactly(2).times.and_return(['file1', 'file2'])
    conflict_detector = ConflictDetector.new(@settings)
    expect(conflict_detector).to receive(:get_conflicts).exactly(3).times.and_return(
      [create_test_git_conflict(branch_a_name: 'path/branch0', branch_b_name: 'path/branch1')],
      [],
      []
    )
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
    def expect_get_conflicts_equals(unfiltered_conflict_list,
                                    expected_conflict_list,
                                    target_branch_name: 'branch_a',
                                    source_branch_names: ['branch_b', 'branch_c'],
                                    alreadyUpToDate: false)
      target_branch = create_test_branch(name: target_branch_name)
      source_branches = source_branch_names.collect { |branch_name| create_test_branch(name: branch_name) }
      conflict_detector = ConflictDetector.new(@settings)
      if unfiltered_conflict_list.empty?
        allow_any_instance_of(Git::Git).to receive(:merge_branches).and_return([!alreadyUpToDate, nil])
      else
        return_values = unfiltered_conflict_list.collect { |conflict| [false, conflict] }
        allow_any_instance_of(Git::Git).to receive(:merge_branches).and_return(*return_values)
      end
      expect(conflict_detector.send(:get_conflicts, target_branch, source_branches)).to \
        match_array(expected_conflict_list)
    end

    it 'includes all conflicts found' do
      conflict_list = [create_test_git_conflict, nil, create_test_git_conflict(branch_b_name: 'branch_d')]
      expected_conflict_list = [conflict_list[0], conflict_list[2]]
      expect_get_conflicts_equals(
        conflict_list,
        expected_conflict_list,
        source_branch_names: ['branch_b', 'branch_c', 'branch_d']
      )
    end

    it 'does not treat branches that do not need merging as conflicts' do
      expect_get_conflicts_equals([], [], alreadyUpToDate: true)
    end

    it 'ignores all conflicts when too many branches have been checked' do
      allow(GlobalSettings).to receive(:maximum_branches_to_check).and_return(1)
      conflict_list = [create_test_git_conflict, create_test_git_conflict(branch_b_name: 'branch_c')]
      expected_conflict_list = [conflict_list[0]]
      expect_get_conflicts_equals(conflict_list, expected_conflict_list)
    end

    it 'ignores branches with the same name' do
      expect_get_conflicts_equals([], [], source_branch_names: ['branch_a'])
    end
  end

  context 'get_conflicting_files_to_ignore' do
    def expect_get_conflicting_files_to_ignore_equals(conflict,
                                                      expected_file_list,
                                                      inherited_conflicting_files: nil,
                                                      ignored_files: nil)
      conflict_detector = ConflictDetector.new(@settings)
      unless inherited_conflicting_files.nil?
        expect(conflict_detector).to receive(:get_inherited_conflicting_files).and_return(inherited_conflicting_files)
      end
      unless ignored_files.nil?
        expect(conflict_detector).to receive(:get_files_to_ignore).and_return(ignored_files)
      end
      expect(conflict_detector.send(:get_conflicting_files_to_ignore, conflict)).to match_array(expected_file_list)
    end

    context 'with no inherited conflicting files' do
      it 'is empty when the "ignore files" list is empty' do
        @settings.ignore_conflicts_in_file_paths = []
        expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['file1', 'file2', 'file3']),
          [],
          inherited_conflicting_files: []
        )
      end

      it 'contains the conflicting files on the "ignore files" list' do
        @settings.ignore_conflicts_in_file_paths = ['file_to_ignore']
        expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['file1', 'file2', 'file3', 'file_to_ignore']),
          ['file_to_ignore'],
          inherited_conflicting_files: []
        )
        expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['file1', 'file2', 'file3']),
          [],
          inherited_conflicting_files: []
        )
      end
    end

    context 'with an empty "ignore files" list' do
      it 'contains inherited conflicting files if present' do
        allow_any_instance_of(Git::Git).to receive(:file_diff_branch_with_ancestor).and_return(
          ['modified_on_branch_a_and_b', 'modified_on_branch_a'],
          ['modified_on_branch_a_and_b', 'modified_on_branch_b']
        )

        expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(
            file_list: ['modified_on_branch_a_and_b', 'modified_on_branch_a', 'modified_on_branch_b']
          ),
          ['modified_on_branch_a', 'modified_on_branch_b'],
          ignored_files: []
        )
      end

      it 'is empty when there are no inherited conflicting files' do
        allow_any_instance_of(Git::Git).to receive(:file_diff_branch_with_ancestor).and_return(
          ['modified_on_branch_a_and_b_1', 'modified_on_branch_a_and_b_2'],
          ['modified_on_branch_a_and_b_1', 'modified_on_branch_a_and_b_2']
        )

        expect_get_conflicting_files_to_ignore_equals(
          create_test_git_conflict(file_list: ['modified_on_branch_a_and_b_1', 'modified_on_branch_a_and_b_2']),
          [],
          ignored_files: []
        )
      end
    end

    it 'contains the union of the inherited and ignored file lists' do
      expect_get_conflicting_files_to_ignore_equals(
        create_test_git_conflict(file_list: ['inherited', 'ignored']),
        ['inherited', 'ignored'],
        inherited_conflicting_files: ['inherited'],
        ignored_files: ['ignored']
      )
    end
  end
end
