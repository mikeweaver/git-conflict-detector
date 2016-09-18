require 'spec_helper'

describe 'JIRA::ClientWrapper' do

  it 'can be created' do
    settings = {
        site: 'https://www.jira.com',
        consumer_key: 'fake_key',
        access_token: 'fake_access_token',
        access_key: 'fake_access_key'
    }
    client = JIRA::ClientWrapper.new(OpenStruct.new(settings))
    expect(client).to_not be_nil
  end

  context 'issues' do

    before do
      settings = {
          site: 'https://www.jira.com',
          consumer_key: 'fake_key',
          access_token: 'fake_access_token',
          access_key: 'fake_access_key'
      }
      @client = JIRA::ClientWrapper.new(OpenStruct.new(settings))
    end

    it 'can find an issue' do
      stub_request(:get, /.*/).to_return(status: 200, body: 'tbd')

      expect(@client.find_issue('ISSUE-1234')).to_not be_nil
    end

    it 'returns nil if the issue does not exist' do
      stub_request(:get, /.*/).to_return(status: 404, body: 'Not Found')

      expect(@client.find_issue('ISSUE-1234')).to be_nil
    end
  end

end
