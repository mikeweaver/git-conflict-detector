require 'spec_helper'

describe 'BranchManager' do

  context 'with settings' do

    before do
      @settings = OpenStruct.new(DEFAULT_CONFLICT_DETECTION_SETTINGS)
      @settings.repository_name = 'repository_name'
      @settings.default_branch_name = 'master'
    end

    context 'filter_branch_list' do

      def expect_filter_branch_list_equals(expected_branch_list)
        branch_manager = BranchManager.new(@settings)
        expect(branch_manager.send(:filter_branch_list, Branch.all)).to match_array(expected_branch_list)
      end

      it 'should include all branches when the "ignore branch" list is empty' do
        @settings.ignore_branches = []
        expect_filter_branch_list_equals([create_test_branch(name: 'straight_match')])
      end

      it 'should ignore branches on the list when the "ignore branch" list is NOT empty' do
        @settings.ignore_branches = ['straight_match', 'regex/.*']
        unfiltered_branch_list = [
            create_test_branch(name: 'straight_match'),
            create_test_branch(name: 'regex/match'),
            create_test_branch(name: 'no_match')]
        expect_filter_branch_list_equals([unfiltered_branch_list[2]])
      end

      it 'should include all branches when the "only branch" list is empty' do
        @settings.only_branches = []
        expect_filter_branch_list_equals([create_test_branch(name: 'straight_match')])
      end

      it 'should include branches on the list when the "only branch" list is NOT empty' do
        @settings.only_branches = ['straight_match', 'regex/.*']
        unfiltered_branch_list = [
            create_test_branch(name: 'straight_match'),
            create_test_branch(name: 'regex/match'),
            create_test_branch(name: 'no_match')]
        expect_filter_branch_list_equals([unfiltered_branch_list[0], unfiltered_branch_list[1]])
      end

      it 'should include all branches when the "modified days ago" is zero' do
        @settings.ignore_branches_modified_days_ago = 0
        expect_filter_branch_list_equals([create_test_branch(name: 'straight_match')])
      end

      it 'should include new branches when the "modified days ago" is > 0' do
        @settings.ignore_branches_modified_days_ago = 1
        unfiltered_branch_list = [
            create_test_branch(name: 'old', last_modified_date: 2.days.ago),
            create_test_branch(name: 'new', last_modified_date: 1.minute.from_now)]
        expect_filter_branch_list_equals([unfiltered_branch_list[1]])
      end
    end

    context 'update_branch_list!' do

      it 'should create new branches, update existing branches, and delete stale branches' do
        # create an old branch that will be deleted because it isn't found in the current git data
        create_test_branch(name: 'old', last_modified_date: 1.minutes.ago)
        create_test_branch(name: 'updatable', last_modified_date: 1.minute.from_now)
        expect(Branch.all.count).to eq(2)

        # mock the current git data
        expect_any_instance_of(Git::Git).to receive(:clone_repository)
        expect_any_instance_of(Git::Git).to receive(:get_branch_list).and_return(
          [create_test_git_branch(name: 'new1'),
           create_test_git_branch(name: 'new2'),
           create_test_git_branch(name: 'updatable')])

        BranchManager.new(@settings).send(:update_branch_list!)

        # only two branches should be in the database, those that start with "new"
        expect(Branch.all.count).to eq(3)
        Branch.all.each do |branch|
          expect(branch.name).to match(/new1|new2|updatable/)
        end
      end
    end
  end

end
