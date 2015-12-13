require 'spec_helper'

describe 'Conflict' do

  DIFFERENT_NAME = 'Different Name'

  before do
    @branches = create_test_branches('Author Name', 3)
  end

  it 'can be created' do
    tested_at = Time.now()
    create_test_conflict(@branches[0], @branches[1], tested_at)

    expect(Conflict.all.size).to eq(1)
  end

  it 're-creating does not update the status_last_changed_date' do
    tested_at1 = Time.now()
    create_test_conflict(@branches[0], @branches[1], tested_at1)
    tested_at2 = Time.now()
    create_test_conflict(@branches[0], @branches[1], tested_at2)

    expect(tested_at1).not_to eq(tested_at2)
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.status_last_changed_date.to_i).to eq(tested_at1.to_i)
    expect(Conflict.first.conflicting_files).to eq(['test/file.rb'])
  end

  it 're-creating with a different file list does update the status_last_changed_date and file list' do
    tested_at1 = Time.now()
    create_test_conflict(@branches[0], @branches[1], tested_at1)
    tested_at2 = Time.now()
    create_test_conflict(@branches[0], @branches[1], tested_at2, ['test/file2.rb'])

    expect(tested_at1).not_to eq(tested_at2)
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.status_last_changed_date.to_i).to eq(tested_at2.to_i)
    expect(Conflict.first.conflicting_files).to eq(['test/file2.rb'])
  end

  it 'can be cleared' do
    create_test_conflict(@branches[0], @branches[1])
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.resolved).to be_falsey
    Conflict.clear!(@branches[0], @branches[1], Time.now())
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.resolved).to be_truthy
    expect(Conflict.first.conflicting_files).to eq([])
  end

  it 'does not raise an error when clearing a non-existent conflict' do
    Conflict.clear!(@branches[0], @branches[1], Time.now())
  end

  it 'does not care about branch order' do
    create_test_conflict(@branches[0], @branches[1])
    create_test_conflict(@branches[1], @branches[0])
    expect(Conflict.all.size).to eq(1)
  end

  it 'treats different branch combinations as unique' do
    create_test_conflict(@branches[0], @branches[1])
    create_test_conflict(@branches[1], @branches[2])
    create_test_conflict(@branches[0], @branches[2])
    expect(Conflict.all.size).to eq(3)
  end

  it 'cannot conflict with itself' do
    expect { create_test_conflict(@branches[0], @branches[0]) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'requires two branches' do
    expect { create_test_conflict(@branches[0], nil) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { create_test_conflict(nil, @branches[0]) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { create_test_conflict(nil, nil, Time.now, ['test/file.rb']) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'requires a file list array' do
    expect { create_test_conflict(@branches[0], @branches[1], Time.now, nil) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { create_test_conflict(@branches[0], @branches[1], Time.now, '') }.to raise_exception(ActiveRecord::RecordInvalid)

    # should not raise
    create_test_conflict(@branches[0], @branches[1], Time.now, [])
  end

  it 'does not allow duplicate conflicts' do
    create_test_conflict(@branches[0], @branches[1])
    conflict = Conflict.new(
        branch_a: @branches[0],
        branch_b: @branches[1],
        conflicting_files: ['test/file.rb'],
        status_last_changed_date: Time.now())
    expect { conflict.save! }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  context 'with branches from multiple users' do
    before do
      @other_branches = create_test_branches(DIFFERENT_NAME, 2)
      @conflict_1 = create_test_conflict(@branches[0], @branches[1])
      @conflict_2 = create_test_conflict(@other_branches[0], @other_branches[1])
    end

    it 'can be looked up by user' do
      conflicts = Conflict.unresolved.by_user(User.where(name: DIFFERENT_NAME).first)
      expect(conflicts.size).to eq(1)
      expect(conflicts[0].branch_a.author.name).to eq(DIFFERENT_NAME)
    end

    it 'can be filtered by status change date' do
      conflicts = Conflict.unresolved.status_changed_after(2.minutes.from_now)
      expect(conflicts.size).to eq(0)

      conflicts = Conflict.unresolved.status_changed_after(2.minutes.ago)
      expect(conflicts.size).to eq(2)
    end

    it 'can be filtered by resolution' do
      unresolved_conflicts = Conflict.unresolved
      expect(unresolved_conflicts.size).to eq(2)

      resolved_conflicts = Conflict.resolved
      expect(resolved_conflicts.size).to eq(0)

      unresolved_conflicts.first.resolved = true
      unresolved_conflicts.first.save!

      resolved_conflicts = Conflict.resolved
      expect(resolved_conflicts.size).to eq(1)
    end

    it 'can be filtered by branch ids' do
      conflicts = Conflict.exclude_branches_with_ids([@branches[0].id, @branches[1].id])
      expect(conflicts).to eq([@conflict_2])

      conflicts = Conflict.exclude_branches_with_ids([@branches[0].id, @branches[1].id, @other_branches[0], @other_branches[1]])
      expect(conflicts.size).to eq(0)

      conflicts = Conflict.exclude_branches_with_ids([])
      expect(conflicts).to eq([@conflict_1, @conflict_2])
    end
    end
  end
end

