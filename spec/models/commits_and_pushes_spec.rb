require 'spec_helper'

describe 'CommitsAndPushes' do
  
  before do
    @commit = create_test_commit
    @push = create_test_push
    # remove head commit so we don't confuse it with the commit we are testing
    @push.commits_and_pushes.destroy_all
    @push.head_commit.destroy
  end

  context 'construction' do
    it 'without errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push)
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
      expect(record.error_list).to eq([])
      expect(record.ignore_errors).to be_falsey
    end

    it 'with errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
      expect(record.error_list).to eq([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
      expect(record.ignore_errors).to be_falsey
    end

    it 'does not create duplicate database records' do
      CommitsAndPushes.create_or_update!(@commit, @push)
      expect(CommitsAndPushes.all.count).to eq(1)

      CommitsAndPushes.create_or_update!(@commit, @push)
      expect(CommitsAndPushes.all.count).to eq(1)
    end

    context 'with ignored errors' do
      before do
        @record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        @record.ignore_errors = true
        @record.save!
      end

      it 'new errors clear the ignore flag' do
        CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER, CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
        @record.reload
        expect(@record.error_list).to eq([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER, CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
        expect(@record.ignore_errors).to be_falsey
      end

      it 'existing errors do not clear the ignore flag' do
        CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        @record.reload
        expect(@record.error_list).to eq([CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        expect(@record.ignore_errors).to be_truthy
      end
    end

  end

  context 'unignored_errors scope' do
    it 'can find pushes with errors' do
      CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      @commit.reload
      expect(@commit.commits_and_pushes.unignored_errors.count).to eq(1)
      expect(CommitsAndPushes.get_error_counts_for_push(@push)).to eq( { CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND => 1 } )
    end

    it 'excludes pushes with ignored errors' do
      record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      record.ignore_errors = true
      record.save!
      @commit.reload
      expect(@commit.commits_and_pushes.unignored_errors.count).to eq(0)
      expect(CommitsAndPushes.get_error_counts_for_push(@push)).to eq( {} )
    end

    it 'excludes pushes without errors' do
      CommitsAndPushes.create_or_update!(@commit, @push, [])
      @commit.reload
      expect(@commit.commits_and_pushes.unignored_errors.count).to eq(0)
      expect(CommitsAndPushes.get_error_counts_for_push(@push)).to eq( {} )
    end
  end
end

