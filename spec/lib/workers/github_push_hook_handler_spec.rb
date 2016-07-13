require 'spec_helper'

describe 'GithubPushHookHandler' do
  def load_payload
    JSON.parse(File.read(Rails.root.join('spec/fixtures/github_push_payload.json')))
  end

  it 'can create be constructed from github push hook payload data' do
    handler = GithubPushHookHandler.new(load_payload)
    expect(handler).not_to be_nil
  end

  it 'handle pushes using delayed jobs' do
    GithubPushHookHandler.new(load_payload).handle!
    expect(Delayed::Job.count).to eq(1)
    expect(Delayed::Worker.new.work_off).to eq([1, 0])
  end
end
