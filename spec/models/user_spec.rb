require 'spec_helper'

describe 'User' do

  it 'can create be constructed from git data' do
    updated_at = DateTime.now
    git_data = Git::Branch.new(
        'mypath/mybranch',
        updated_at,
        'Author Name',
        'author@email.com')
    user = User.create_from_git_data(git_data)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('author@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
  end

  it 'can have multiple branches related to it' do
    (0..1).each do |i|
      git_data = Git::Branch.new(
          "path/branch#{i}",
          DateTime.now,
          'Author Name',
          'author@email.com')
      Branch.create_from_git_data(git_data)
    end
    user = User.where(email: 'author@email.com').first
    expect(user.branches.size).to eq(2)
  end

  it 'will not allow duplicate name/email combinations' do
    user1 = User.create(name: 'Author Name', email: 'author@email.com')
    user1.save
    # rails silently allows this to succedd, but does not create a duplicate
    user2 = User.create(name: 'Author Name', email: 'author@email.com')
    user2.save
    expect(User.all.size).to eq(1)
  end

  it 'requires name and email address' do
    expect { User.create(name: 'Author Name') }.to raise_exception(ActiveRecord::StatementInvalid)
    expect { User.create(email: 'author@email.com') }.to raise_exception(ActiveRecord::StatementInvalid)
  end

end

