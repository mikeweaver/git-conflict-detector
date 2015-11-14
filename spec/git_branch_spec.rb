require 'spec_helper'

describe 'GitBranch' do

  it 'can be created' do
    last_modified_date = Time.now
    conflict = Git::GitBranch.new('name', last_modified_date , 'author_name', 'author@email.com')

    expect(conflict.name).to eq('name')
    expect(conflict.last_modified_date).to eq(last_modified_date)
    expect(conflict.author_name).to eq('author_name')
    expect(conflict.author_email).to eq('author@email.com')
  end
end
