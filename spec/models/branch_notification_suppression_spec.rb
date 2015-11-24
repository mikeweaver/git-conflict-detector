require 'spec_helper'

describe 'BranchNotificationSuppression' do

  def create_test_branches(user_name, count)
    branches = []
    (0..count - 1).each do |i|
      git_data = Git::GitBranch.new(
          "path/#{user_name}/branch#{i}",
          DateTime.now,
          user_name,
          'author@email.com')
      branches << Branch.create_from_git_data!(git_data)
    end
    branches
  end

  before do
    @branches_a = create_test_branches('Author A', 2)
    @branches_b = create_test_branches('Author B', 2)
  end

  it 'can be created with a suppression date' do
    suppress_until = 4.days.from_now
    suppression = BranchNotificationSuppression.create!(@branches_a[0].author, @branches_b[0], suppress_until)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.branch.id).to eq(@branches_b[0].id)
    expect(suppression.suppress_until).to eq(suppress_until)
  end

  it 'can be created without a suppression date' do
    suppression = BranchNotificationSuppression.create!(@branches_a[0].author, @branches_b[0], nil)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.branch.id).to eq(@branches_b[0].id)
    expect(suppression.suppress_until).to be_nil
  end

  it 'can be filtered by user' do
    BranchNotificationSuppression.create!(@branches_a[0].author, @branches_b[0], nil)
    BranchNotificationSuppression.create!(@branches_b[0].author, @branches_b[0], nil)

    suppressions = BranchNotificationSuppression.by_user(@branches_a[0].author)
    expect(suppressions.size).to eq(1)
  end

  it 'can be filtered by suppression date' do
    BranchNotificationSuppression.create!(@branches_a[0].author, @branches_b[0], nil)
    BranchNotificationSuppression.create!(@branches_a[0].author, @branches_b[1], 4.days.from_now)
    BranchNotificationSuppression.create!(@branches_b[0].author, @branches_a[1], 4.days.ago)

    suppressions = BranchNotificationSuppression.not_expired
    expect(suppressions.size).to eq(2)
  end
end

