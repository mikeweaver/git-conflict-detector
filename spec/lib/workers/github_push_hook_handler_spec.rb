require 'spec_helper'

describe 'GithubPushHookHandler' do
  def load_payload
    JSON.parse(File.read(Rails.root.join('spec/fixtures/github_push_payload.json')))
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
    handler = GithubPushHookHandler.new(load_payload)
    expect(handler).not_to be_nil
  end

  it 'sets sha status when queued' do
    mock_status_request(Github::Api::Status::STATE_PENDING, GithubPushHookHandler::PENDING_DESCRIPTION)
    GithubPushHookHandler.new(load_payload).queue!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off(1)).to eq([1, 0])

    # it should have queued another job
    expect(Delayed::Job.count).to eq(1)
  end

  it 'sets sha status after processing' do
    mock_status_request(Github::Api::Status::STATE_SUCCESS, GithubPushHookHandler::SUCCESS_DESCRIPTION)
    GithubPushHookHandler.new(load_payload).process!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job
    expect(Delayed::Worker.new.work_off).to eq([1, 0])
  end

  it 'retries on failure' do
    mock_failed_status_request
    GithubPushHookHandler.new(load_payload).process!

    # a job should be queued
    expect(Delayed::Job.count).to eq(1)

    # process the job, it will fail
    expect(Delayed::Worker.new.work_off).to eq([0, 1])

    # the job should still be queued
    expect(Delayed::Job.count).to eq(1)
  end
end
