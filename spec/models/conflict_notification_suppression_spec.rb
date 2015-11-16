require 'spec_helper'

describe 'ConflictNotificationSuppression' do

  def create_test_branches(user_name, count)
    branches = []
    (0..count - 1).each do |i|
      git_data = Git::GitBranch.new(
          "path/#{user_name}/branch#{i}",
          DateTime.now,
          user_name,
          'author@email.com')
      branches << Branch.create_from_git_data(git_data)
    end
    branches
  end

  before do
    @branches_a = create_test_branches('Author A', 2)
    @branches_b = create_test_branches('Author B', 2)
  end

  it 'can be created with a suppression date' do
    suppress_until = 4.days.from_now
    suppression = ConflictNotificationSuppression.create(@branches_a[0].author, @branches_b[0], suppress_until)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.branch.id).to eq(@branches_b[0].id)
    expect(suppression.suppress_until).to eq(suppress_until)
  end

  it 'can be created without a suppression date' do
    suppression = ConflictNotificationSuppression.create(@branches_a[0].author, @branches_b[0], nil)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.branch.id).to eq(@branches_b[0].id)
    expect(suppression.suppress_until).to be_nil
  end

end

