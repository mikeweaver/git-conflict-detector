require 'spec_helper'

describe 'GithubPushHookHandler' do
  def payload
    @payload ||= JSON.parse(File.read(Rails.root.join('spec/fixtures/github_push_payload.json')))
  end

  def jira_issue_query_response
    @jira_issue_query_response ||= JSON.parse(File.read(Rails.root.join('spec/fixtures/jira_issue_response.json')))
  end

  def mock_status_request(state, description)
    api = instance_double(Github::Api::Status)
    expect(api).to receive(:set_status).with('OwnerName',
                                             'reponame',
                                             '6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25',
                                             GithubPushHookHandler::CONTEXT_NAME,
                                             state,
                                             description,
                                             anything).and_return({})
    expect(Github::Api::Status).to receive(:new).and_return(api)
  end

  def mock_failed_status_request
    api = instance_double(Github::Api::Status)
    expect(api).to receive(:set_status).and_raise(Net::HTTPServerException.new(nil, nil))
    expect(Github::Api::Status).to receive(:new).and_return(api)
  end

  it 'can create be constructed from github push hook payload data' do
    handler = GithubPushHookHandler.new(payload)
    expect(handler).not_to be_nil
  end

  it 'sets sha status when queued' do
    mock_status_request(
        Github::Api::Status::STATE_PENDING,
        GithubPushHookHandler::STATE_DESCRIPTIONS[Github::Api::Status::STATE_PENDING])

    GithubPushHookHandler.new(payload).queue!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])

    # it should have queued another job
    expect(Delayed::Job.count).to eq(1)
  end

  it 'sets sha status after processing' do
    mock_status_request(
        Github::Api::Status::STATE_SUCCESS,
        GithubPushHookHandler::STATE_DESCRIPTIONS[Github::Api::Status::STATE_SUCCESS])
    expect_any_instance_of(GithubPushHookHandler).to receive(:handle_process_request!).and_return(Github::Api::Status::STATE_SUCCESS)

    GithubPushHookHandler.new(payload).process!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off).to eq([1, 0])
  end

  it 'retries on failure' do
    mock_failed_status_request
    expect_any_instance_of(GithubPushHookHandler).to receive(:handle_process_request!).and_return(Github::Api::Status::STATE_SUCCESS)

    GithubPushHookHandler.new(payload).process!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job, it will fail
    expect(Delayed::Worker.new.work_off).to eq([0, 1])

    # the job should still be queued
    expect(Delayed::Job.count).to eq(1)
  end

  it 'can process payloads' do
    commits = [Git::GitCommit.new('efd778098239838c165ffab2f12ad293f32824c8', 'STORY-1234 Description1', nil, 'Author 1', 'author1@email.com'),
               Git::GitCommit.new('667f3e5347c48c04663209682642fd8d6d93fde2', 'STORY-5678 Description2', nil, 'Author 2', 'author2@email.com')]
    expect_any_instance_of(Git::Git).to receive(:commits_diff_branch_with_ancestor).and_return(commits)

    ['STORY-1234', 'STORY-5678'].each do |ticket_number|
      response = jira_issue_query_response.clone
      response['key'] = ticket_number
      stub_request(:get, /.*#{ticket_number}/).to_return(:status => 200, :body => response.to_json)
    end

    GithubPushHookHandler.new(payload).send(:handle_process_request!)
  end

  # TODO:
  # commits without ticket numbers
  # ticket numbers that don't exist
  # tickets in invalid states
end
