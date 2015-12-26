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

end
