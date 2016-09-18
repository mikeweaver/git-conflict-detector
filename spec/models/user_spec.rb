require 'spec_helper'

describe 'User' do
  def jira_user
    jira_issue_json = JSON.parse(File.read(Rails.root.join('spec/fixtures/jira_issue_response.json')))
    @jira_user ||= JIRA::Resource::UserFactory.new(nil).build(jira_issue_json['fields']['assignee'])
  end

  it 'can create be constructed from git data' do
    git_data = Git::GitBranch.new(
        'repository_name',
        'mypath/mybranch',
        DateTime.now,
        'Author Name',
        'author@email.com')
    user = User.create_from_git_data!(git_data)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('author@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
    expect(user.unsubscribed).to be_falsey
  end

  it 'can create be constructed from jira data' do
    user = User.create_from_jira_data!(jira_user)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('author@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
    expect(user.unsubscribed).to be_falsey
  end

  it 'can have multiple branches related to it' do
    create_test_branches(author_email: 'author@email.com')
    user = User.where(email: 'author@email.com').first
    expect(user.branches.size).to eq(2)
  end

  it 'can have multiple commits related to it' do
    create_test_commits(author_email: 'author@email.com')
    user = User.where(email: 'author@email.com').first
    expect(user.commits.size).to eq(2)
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

  context 'with two users' do
    before do
      @user_1 = User.create(name: 'Author Name 1', email: 'email1@email.com')
      @user_2 = User.create(name: 'Author Name 2', email: 'email2@email.com')
    end

    it 'can return list of users filtered by email address' do
      users = User.users_with_emails([])
      expect(users).to eq([@user_1, @user_2])

      users = User.users_with_emails([@user_1.email])
      expect(users).to eq([@user_1])

      users = User.users_with_emails(['notinlist@email.com'])
      expect(users).to eq([])
    end

    it 'can be unsubscribed by id' do
      User.unsubscribe_by_id!(@user_1.id)
      expect(@user_1.reload.unsubscribed).to be_truthy
      expect(@user_2.reload.unsubscribed).to be_falsey
    end

    it 'can be unsubscribed' do
      @user_1.unsubscribe!
      expect(@user_1.reload.unsubscribed).to be_truthy
      expect(@user_2.reload.unsubscribed).to be_falsey
    end

    it 'can be filtered by unsubscribe status' do
      expect(User.subscribed_users.size).to eq(2)
      @user_1.unsubscribe!
      expect(User.subscribed_users).to eq([@user_2])
    end
  end

end

