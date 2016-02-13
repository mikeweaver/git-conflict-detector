require 'spec_helper'

describe 'Git::GitError' do

  it 'can be raised' do
    last_modified_date = Time.now
    expect {raise Git::GitError.new('command', 200, 'error_message')}.to raise_exception(Git::GitError, "Git command command failed with exit code 200. Message:\nerror_message")
  end

  it 'can be printed' do
    begin
      raise Git::GitError.new('command', 200, 'error_message')
    rescue Git::GitError => e
      expect(e.message).to eq("Git command command failed with exit code 200. Message:\nerror_message")
    end
  end
end
