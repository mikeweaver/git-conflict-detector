require 'spec_helper'

describe 'Push' do
  def payload
    @payload ||= Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  it 'can create be constructed from github data' do
    push = Push.create_from_github_data!(payload)
    expect(push.status).to eq(Github::Api::Status::STATE_PENDING.to_s)
    expect(push.head_commit).to_not be_nil
    expect(push.branch).to_not be_nil
    expect(push.commits.count).to eq(1)
    expect(push.jira_issues.count).to eq(0)
    expect(push.created_at).to_not be_nil
    expect(push.updated_at).to_not be_nil
  end

  it 'does not create duplicate database records' do
    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(1)

    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(1)
  end

  context 'commits' do
    before do
      @push = Push.create_from_github_data!(payload)
      expect(@push.commits.count).to eq(1)
    end
    
    it 'can own some' do
      create_test_commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, @push)
      end
      @push.reload
      expect(@push.commits.count).to eq(3)
      expect(@push.has_commits_with_errors?).to be_falsey
      expect(@push.commits_with_errors.count).to eq(0)
      expect(@push.has_errors?).to be_falsey
      expect(@push.has_commits_with_unignored_errors?).to be_falsey
    end

    it 'can detect ones with errors' do
      expect(@push.has_commits_with_errors?).to be_falsey
      expect(@push.commits_with_errors.count).to eq(0)
      expect(@push.has_errors?).to be_falsey
      expect(@push.has_commits_with_unignored_errors?).to be_falsey
      create_test_commits.each do |commit|
        CommitsAndPushes.create_or_update!(commit, @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      end
      expect(@push.has_commits_with_errors?).to be_truthy
      expect(@push.commits_with_errors.count).to eq(2)
      expect(@push.has_errors?).to be_truthy
      expect(@push.has_commits_with_unignored_errors?).to be_truthy
    end

    it 'can compute status' do
      CommitsAndPushes.create_or_update!(create_test_commit(sha: create_test_sha), @push)
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
      error_record = CommitsAndPushes.create_or_update!(create_test_commit(sha: create_test_sha), @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_FAILED)
      error_record.ignore_errors = true
      error_record.save!
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
    end
  end

  context 'jira_issues' do
    before do
      @push = Push.create_from_github_data!(payload)
    end

    it 'can own some' do
      expect(@push.has_jira_issues).to be_falsey
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      @push.reload
      expect(@push.has_jira_issues).to be_truthy
      expect(@push.jira_issues.count).to eq(1)
      expect(@push.has_jira_issues_with_errors?).to be_falsey
      expect(@push.jira_issues_with_errors.count).to eq(0)
      expect(@push.has_errors?).to be_falsey
      expect(@push.has_jira_issues_with_unignored_errors?).to be_falsey
    end

    it 'can detect ones with errors' do
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      expect(@push.has_jira_issues_with_errors?).to be_falsey
      expect(@push.jira_issues_with_errors.count).to eq(0)
      expect(@push.has_errors?).to be_falsey
      expect(@push.has_jira_issues_with_unignored_errors?).to be_falsey

      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-1234'), @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-5468'), @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      expect(@push.has_jira_issues_with_errors?).to be_truthy
      expect(@push.jira_issues_with_errors.count).to eq(2)
      expect(@push.has_errors?).to be_truthy
      expect(@push.has_jira_issues_with_unignored_errors?).to be_truthy
    end

    it 'can compute status' do
      JiraIssuesAndPushes.create_or_update!(create_test_jira_issue, @push)
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
      error_record = JiraIssuesAndPushes.create_or_update!(create_test_jira_issue(key: 'WEB-1234'), @push, [CommitsAndPushes::ERROR_ORPHAN_JIRA_ISSUE_NOT_FOUND])
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_FAILED)
      error_record.ignore_errors = true
      error_record.save!
      expect(@push.compute_status!).to eq(Github::Api::Status::STATE_SUCCESS)
    end
  end
end

