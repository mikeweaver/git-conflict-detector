require 'spec_helper'

describe 'Commit' do
  def payload
    Github::Api::PushHookPayload.new(load_json_fixture('github_push_payload'))
  end

  it 'can create be constructed from github data' do
    commit = Commit.create_from_github_data!(payload)
    expect(commit.sha).to eq('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25')
    expect(commit.message).to_not be_nil
    expect(commit.author.name).to_not be_nil
    expect(commit.author.email).to_not be_nil
    expect(commit.created_at).to_not be_nil
    expect(commit.updated_at).to_not be_nil
  end

  it 'can create be constructed from a git commit' do
    git_commit = Git::GitCommit.new(
        '6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25',
        'test message',
        Time.now,
        'author name',
        'author@email.com')
    commit = Commit.create_from_git_commit!(git_commit)
    expect(commit.sha).to eq('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25')
    expect(commit.message).to_not be_nil
    expect(commit.author.name).to_not be_nil
    expect(commit.author.email).to_not be_nil
    expect(commit.created_at).to_not be_nil
    expect(commit.updated_at).to_not be_nil
  end

  it 'does not create duplicate database records' do
    Commit.create_from_github_data!(payload)
    expect(Commit.all.count).to eq(1)

    Commit.create_from_github_data!(payload)
    expect(Commit.all.count).to eq(1)
  end

  it 'rejects shas that are all zeros' do
    payload_hash = load_json_fixture('github_push_payload')
    payload_hash['head_commit']['id'] = '0' * 40

    expect { Commit.create_from_github_data!(Github::Api::PushHookPayload.new(payload_hash)) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  context 'with an existing commit' do

    before do
      @commit = Commit.create_from_github_data!(payload)
    end

    it 'prints its sha when stringified' do
      expect(@commit.to_s).to eq('6d8cc7db8021d3dbf90a4ebd378d2ecb97c2bc25')
    end

    it 'has a short sha' do
      expect(@commit.short_sha).to eq('6d8cc7d')
    end
  end

  it 'can belong to a JIRA issue' do
    jira_issue = create_test_jira_issue
    commit = Commit.create_from_github_data!(payload)
    commit.jira_issue = jira_issue
    commit.save!
    expect(commit.jira_issue.id).to eq(jira_issue.id)
  end

  context 'pushes' do
    before do
      @commit = create_test_commit
      @push = create_test_push
      # remove head commit so we don't confuse it with the commit we are testing
      @push.commits_and_pushes.destroy_all
      @push.head_commit.destroy
      expect(@commit.pushes.count).to eq(0)
    end

    it 'can belong to one' do
      CommitsAndPushes.create_or_update!(@commit, @push)
      @commit.reload
      @push.reload
      expect(@commit.pushes.count).to eq(1)
      expect(@push.commits.count).to eq(1)
    end

    context 'has_unignored_errors?' do
      it 'includes pushes with errors' do
        CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        @commit.reload
        expect(@commit.has_unignored_errors?(@push)).to be_truthy
      end

      it 'excludes pushes with ignored errors' do
        record = CommitsAndPushes.create_or_update!(@commit, @push, [CommitsAndPushes::ERROR_ORPHAN_NO_JIRA_ISSUE_NUMBER])
        record.ignore_errors = true
        record.save!
        @commit.reload
        expect(@commit.has_unignored_errors?(@push)).to be_falsey
      end

      it 'excludes pushes without errors' do
        CommitsAndPushes.create_or_update!(@commit, @push, [])
        @commit.reload
        expect(@commit.has_unignored_errors?(@push)).to be_falsey
      end
    end
  end
end

