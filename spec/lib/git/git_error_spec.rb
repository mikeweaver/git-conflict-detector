require 'spec_helper'

describe 'GitError' do

  it 'can be raised' do
    last_modified_date = Time.now
    expect {raise Git::GitError.new('command', 200, 'error_message')}.to raise_exception(Git::GitError)
  end

  it 'can be printed' do
    begin
      raise Git::GitError.new('command', 200, 'error_message')
    rescue Git::GitError => e
      expect(e.message).to match(/.*command.*200.*\n.*error_message.*/)
    end
  end
end
