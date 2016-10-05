require 'spec_helper'

describe 'JiraIssuesAndPushes' do
  def jira_issue
    @jira_issue ||= JIRA::Resource::IssueFactory.new(nil).build(load_json_fixture('jira_issue_response'))
  end

  before do
    @issue = JiraIssue.create_from_jira_data!(jira_issue)
    @push = create_test_push
  end

  context 'construction' do
    it 'without errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push)
      @issue.reload
      @push.reload
      expect(@issue.pushes.count).to eq(1)
      expect(@push.jira_issues.count).to eq(1)
      expect(record.error_list).to eq([])
      expect(record.ignore_errors).to be_falsey
    end

    it 'with errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
      @issue.reload
      @push.reload
      expect(@issue.pushes.count).to eq(1)
      expect(@push.jira_issues.count).to eq(1)
      expect(record.error_list).to eq([JiraIssuesAndPushes::ERROR_WRONG_STATE])
      expect(record.ignore_errors).to be_falsey
    end

    it 'does not create duplicate database records' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(JiraIssuesAndPushes.all.count).to eq(1)

      JiraIssuesAndPushes.create_or_update!(@issue, @push)
      expect(JiraIssuesAndPushes.all.count).to eq(1)
    end

    context 'with ignored errors' do
      before do
        @record = JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
        @record.ignore_errors = true
        @record.save!
      end

      it 'new errors clear the ignore flag' do
        JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_NO_COMMITS])
        @record.reload
        expect(@record.error_list).to eq([JiraIssuesAndPushes::ERROR_WRONG_STATE, JiraIssuesAndPushes::ERROR_NO_COMMITS])
        expect(@record.ignore_errors).to be_falsey
      end

      it 'existing errors do not clear the ignore flag' do
        JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_STATE])
        @record.reload
        expect(@record.error_list).to eq([JiraIssuesAndPushes::ERROR_WRONG_STATE])
        expect(@record.ignore_errors).to be_truthy
      end
    end

  end

  context 'unignored_errors scope' do
    it 'can find pushes with errors' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE])
      @issue.reload
      expect(@issue.jira_issues_and_pushes.unignored_errors.count).to eq(1)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to eq( { JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE => 1 } )
    end

    it 'excludes pushes with ignored errors' do
      record = JiraIssuesAndPushes.create_or_update!(@issue, @push, [JiraIssuesAndPushes::ERROR_WRONG_DEPLOY_DATE])
      record.ignore_errors = true
      record.save!
      @issue.reload
      expect(@issue.jira_issues_and_pushes.unignored_errors.count).to eq(0)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to eq( {} )
    end

    it 'excludes pushes without errors' do
      JiraIssuesAndPushes.create_or_update!(@issue, @push, [])
      @issue.reload
      expect(@issue.jira_issues_and_pushes.unignored_errors.count).to eq(0)
      expect(JiraIssuesAndPushes.get_error_counts_for_push(@push)).to eq( {} )
    end
  end
end

