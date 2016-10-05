require 'spec_helper'

describe 'Push' do
  def payload
    @payload ||= Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  it 'can create be constructed from github data' do
    push = Push.create_from_github_data!(payload)
    expect(push.status).to eq(Github::Api::Status::STATE_PENDING.to_s)
    expect(push.head_commit).to_not be_nil
    expect(push.branch).to_not be_nil
    expect(push.commits.count).to eq(1)
    expect(push.jira_issues.count).to eq(0)
    expect(push.created_at).to_not be_nil
    expect(push.updated_at).to_not be_nil
  end

  it 'does not create duplicate database records' do
    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(1)

    Push.create_from_github_data!(payload)
    expect(Push.all.count).to eq(1)
  end

  context 'commits' do
    before do
      @push = Push.create_from_github_data!(payload)
      expect(@push.commits.count).to eq(1)
    end
    
    it 'can own some' do
      create_test_commits.each do |commit|
        commit.pushes << @push
        commit.save!
      end
      @push.reload
      expect(@push.commits.count).to eq(3)
    end

    it 'can find orphans' do
      issue = create_test_jira_issue
      issue.pushes << @push
      issue.save!
      commit = @push.commits.first
      commit.jira_issue = issue
      commit.save!
      @push.reload
      expect(@push.has_orphan_commits).to be_falsey

      create_test_commits.each do |commit|
        commit.pushes << @push
        commit.save!
      end
      @push.reload
      expect(@push.commits.count).to eq(3)
      expect(@push.has_orphan_commits).to be_truthy
      expect(@push.orphan_commits.count).to eq(2)
    end
  end

  context 'jira_issues' do
    it 'can own some' do
      push = Push.create_from_github_data!(payload)
      expect(push.has_jira_issues).to be_falsey
      issue = create_test_jira_issue
      issue.pushes << push
      issue.save!
      push.reload
      expect(push.has_jira_issues).to be_truthy
      expect(push.jira_issues.count).to eq(1)
    end
  end

end

