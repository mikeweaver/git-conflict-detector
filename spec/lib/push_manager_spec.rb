require 'spec_helper'

describe 'PushManager' do
  def payload
    @payload ||= Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  def jira_issue_query_response
    @jira_issue_query_response ||= load_json_fixture('jira_issue_response')
  end

  it 'can process payloads' do
    commits = [Git::GitCommit.new('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25', 'STORY-1234 Description1', nil, 'Author 1', 'author1@email.com'),
               Git::GitCommit.new('667f3e5347c48c04663209682642fd8d6d93fde2', 'STORY-5678 Description2', nil, 'Author 2', 'author2@email.com')]
    expect_any_instance_of(Git::Git).to receive(:commit_diff_refs).and_return(commits)

    ['STORY-1234', 'STORY-5678'].each do |ticket_number|
      response = jira_issue_query_response.clone
      response['key'] = ticket_number
      stub_request(:get, /.*#{ticket_number}/).to_return(:status => 200, :body => response.to_json)
    end

    PushManager.process_push(Push.create_from_github_data!(payload))
    push = Push.first
    expect(push.commits.count).to eq(2)
    expect(push.jira_issues.count).to eq(2)
    push.jira_issues.each do |jira_issue|
      expect(jira_issue.commits.count).to eq(1)
    end
  end

  # TODO:
  # commits without ticket numbers
  # ticket numbers that don't exist
  # tickets in invalid states
end
