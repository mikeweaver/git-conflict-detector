require 'spec_helper'

describe 'ConflictNotificationSuppression' do
  before do
    @branches_a = create_test_branches(author_name: 'Author A', count: 2)
    @branches_b = create_test_branches(author_name: 'Author B', count: 2)
    @conflict = create_test_conflict(@branches_a[0], @branches_b[1])
  end

  it 'can be created with a suppression date' do
    suppress_until = 4.days.from_now
    suppression = ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict, suppress_until)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.conflict.id).to eq(@conflict.id)
    expect(suppression.suppress_until).to eq(suppress_until)
  end

  it 'can be created without a suppression date' do
    suppression = ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict, nil)

    expect(suppression.user.id).to eq(@branches_a[0].author.id)
    expect(suppression.conflict.id).to eq(@conflict.id)
    expect(suppression.suppress_until).to be_nil
  end

  it 'can be filtered by user' do
    ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict, nil)
    ConflictNotificationSuppression.create!(@branches_b[0].author, @conflict, nil)

    suppressions = ConflictNotificationSuppression.by_user(@branches_a[0].author)
    expect(suppressions.size).to eq(1)
  end

  it 'can be filtered by suppression date' do
    conflict_b = create_test_conflict(@branches_a[1], @branches_b[1])

    ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict, nil)
    ConflictNotificationSuppression.create!(@branches_a[0].author, conflict_b, 4.days.from_now)
    ConflictNotificationSuppression.create!(@branches_b[0].author, @conflict, 4.days.ago)

    suppressions = ConflictNotificationSuppression.not_expired
    expect(suppressions.size).to eq(2)
  end

  it 'can return list of suppressed conflict ids filtered by user' do
    conflict_b = create_test_conflict(@branches_a[1], @branches_b[1])

    ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict, nil)
    ConflictNotificationSuppression.create!(@branches_a[0].author, conflict_b, 4.days.from_now)
    ConflictNotificationSuppression.create!(@branches_b[0].author, @conflict, 4.days.from_now)

    conflict_ids = ConflictNotificationSuppression.suppressed_conflict_ids(@branches_a[0].author)
    expect(conflict_ids).to eq([@conflict.id, conflict_b.id])
  end
end
