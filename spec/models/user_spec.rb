require 'spec_helper'

describe 'User' do

  it 'can create be constructed from git data' do
    updated_at = DateTime.now
    git_data = Git::GitBranch.new(
        'mypath/mybranch',
        updated_at,
        'Author Name',
        'author@email.com')
    user = User.create_from_git_data!(git_data)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('author@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
  end

  it 'can have multiple branches related to it' do
    create_test_branches('author@email.com', 2)
    user = User.where(email: 'author@email.com').first
    expect(user.branches.size).to eq(2)
  end

  it 'will not allow duplicate name/email combinations' do
    user1 = User.create(name: 'Author Name', email: 'author@email.com')
    user1.save!
    user2 = User.create(name: 'Author Name', email: 'author@email.com')

    expect { user2.save! }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'requires name and email address' do
    expect { User.create(name: 'Author Name') }.to raise_exception(ActiveRecord::StatementInvalid)
    expect { User.create(email: 'author@email.com') }.to raise_exception(ActiveRecord::StatementInvalid)
  end

end

