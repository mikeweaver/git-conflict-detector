require 'spec_helper'

describe 'User' do
  def jira_user
    @jira_user ||= JIRA::Resource::UserFactory.new(nil).build(
      load_json_fixture('jira_issue_response')['fields']['assignee']
    )
  end

  it 'can create be constructed from jira data' do
    user = User.create_from_jira_data!(jira_user)

    expect(user.name).to eq('Author Name')
    expect(user.email).to eq('author@email.com')
    expect(user.created_at).not_to be_nil
    expect(user.updated_at).not_to be_nil
    expect(user.unsubscribed).to be_falsey
  end

  context 'with two users' do
    before do
      @user_1 = User.create(name: 'Author Name 1', email: 'email1@email.com')
      @user_2 = User.create(name: 'Author Name 2', email: 'email2@email.com')
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
