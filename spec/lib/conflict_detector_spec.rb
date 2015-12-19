require 'spec_helper'

describe 'ConflictDetector' do

  def create_test_git_branches
    test_branches = []
    (0..2).each do |i|
      test_branches << Git::GitBranch.new(
          "path/branch#{i}",
          DateTime.now,
          'Author Name',
          'author@email.com')
    end
    test_branches
  end

  it 'works' do
    start_time = Time.now
    conflict_detector = ConflictDetector.new(GlobalSettings.repos_to_check['MyRepo'])
    expect(conflict_detector).to receive(:setup_repo)
    expect(conflict_detector).to receive(:get_branch_list) { create_test_git_branches }
    expect(conflict_detector).to receive(:get_conflicts ).exactly(3).times.and_return(
      [Git::GitConflict.new('path/branch0', 'path/branch1', ['dir/file.rb'])], [], [])
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

end
