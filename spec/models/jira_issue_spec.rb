require 'spec_helper'

describe 'JiraIssue' do
  def jira_issue
    @jira_issue ||= JIRA::Resource::IssueFactory.new(nil).build(load_json_fixture('jira_issue_response'))
  end

  def jira_sub_task
    @jira_sub_task ||= JIRA::Resource::IssueFactory.new(nil).build(load_json_fixture('jira_sub_task_response'))
  end

  it 'can create be constructed from jira data' do
    issue = JiraIssue.create_from_jira_data!(jira_issue)

    expect(issue.key).to eq('STORY-4380')
    expect(issue.summary).to eq('This is the issue summary')
    expect(issue.issue_type).to eq('Story')
    expect(issue.status).to eq('Code Review')
    expect(issue.targeted_deploy_date).to eq(Date.parse('2016-09-21'))
    expect(issue.parent_issue).to be_nil
    expect(issue.pushes).to eq([])
    expect(issue.assignee.name).to eq('Author Name')
    expect(issue.assignee.email).to eq('author@email.com')
    expect(issue.created_at).not_to be_nil
    expect(issue.updated_at).not_to be_nil
  end

  it 'does not create duplicate database records' do
    JiraIssue.create_from_jira_data!(jira_issue)
    expect(JiraIssue.all.count).to eq(1)

    JiraIssue.create_from_jira_data!(jira_issue)
    expect(JiraIssue.all.count).to eq(1)
  end

  it 'rejects keys that are invalid' do
    jira_issue.attrs['key'] = 'invalidkey'

    expect { JiraIssue.create_from_jira_data!(jira_issue) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  context 'assignee' do
    it 'can be nil' do
      issue_json = load_json_fixture('jira_issue_response')
      issue_json['fields']['assignee'] = nil
      issue = JiraIssue.create_from_jira_data!(JIRA::Resource::IssueFactory.new(nil).build(issue_json))
      expect(issue.assignee).to be_nil
    end

    it 'can be changed' do
      orginal_issue = JiraIssue.create_from_jira_data!(jira_issue)

      jira_issue.assignee.attrs['name'] = 'Other User'
      jira_issue.assignee.attrs['emailAddress'] = 'otheruser@test.com'

      updated_issue = JiraIssue.create_from_jira_data!(jira_issue)

      expect(User.count).to eq(2)
      expect(orginal_issue.assignee.id).not_to eq(updated_issue.assignee.id)
      expect(updated_issue.assignee.email = 'otheruser@test.com')
    end
  end

  context 'commits' do
    it 'can own some' do
      issue = JiraIssue.create_from_jira_data!(jira_issue)
      expect(issue.commits.count).to eq(0)
      create_test_commits.each do |commit|
        commit.jira_issue = issue
        commit.save!
      end
      issue.reload
      expect(issue.commits.count).to eq(2)
    end
  end

  context 'subtask parent' do
    it 'gets created if it does not exist' do
      child_issue = JiraIssue.create_from_jira_data!(jira_sub_task)
      expect(child_issue.key).to eq('STORY-4240')
      expect(child_issue.parent_issue.key).to eq('STORY-4380')
      expect(JiraIssue.count).to eq(2)
    end

    it 'uses parent if it exists' do
      # create the parent issue for the child to be related to
      parent_issue = JiraIssue.create_from_jira_data!(jira_issue)
      child_issue = JiraIssue.create_from_jira_data!(jira_sub_task)
      expect(child_issue.key).to eq('STORY-4240')
      expect(child_issue.parent_issue.key).to eq('STORY-4380')
      expect(child_issue.parent_issue).to eq(parent_issue)
      expect(JiraIssue.count).to eq(2)
    end

    it 'can be changed' do
      orginal_issue = JiraIssue.create_from_jira_data!(jira_sub_task)

      jira_sub_task.parent['key'] = 'STORY-9999'

      updated_issue = JiraIssue.create_from_jira_data!(jira_sub_task)

      expect(JiraIssue.count).to eq(3)
      expect(orginal_issue.parent_issue.id).not_to eq(updated_issue.parent_issue.id)
      expect(updated_issue.parent_issue.key = 'STORY-9999')
    end
  end
end

