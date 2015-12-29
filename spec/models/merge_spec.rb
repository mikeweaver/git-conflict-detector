require 'spec_helper'

describe 'Merge' do

  DIFFERENT_NAME = 'Different Name'

  before do
    @branches = create_test_branches(author_name: 'Author Name', count: 3)
  end

  it 'can be created' do
    create_test_merge(@branches[0], @branches[1], successful: true)
    create_test_merge(@branches[0], @branches[2], successful: false)
    expect(Merge.all.size).to eq(2)
  end

  it 'does not allow duplicate merges' do
    create_test_merge(@branches[0], @branches[1])
    expect { create_test_merge(@branches[0], @branches[1]) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'cannot merge with itself' do
    expect { create_test_merge(@branches[0], @branches[0]) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'requires two branches' do
    expect { create_test_merge(@branches[0], nil) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { create_test_merge(nil, @branches[0]) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { create_test_merge(nil, nil) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'does not allow merges between repositories' do
    branch_in_different_repository = create_test_branch(repository_name: 'other_repository_name')
    expect { create_test_merge(@branches[0], branch_in_different_repository) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  context 'with branches from multiple users' do
    before do
      @other_branches = create_test_branches(author_name: DIFFERENT_NAME, count: 2)
      @merge_1 = create_test_merge(@branches[0], @branches[1])
      @merge_2 = create_test_merge(@other_branches[0], @other_branches[1])
    end

    it 'can be looked up by user' do
      merges = Merge.by_target_user(User.where(name: DIFFERENT_NAME).first)
      expect(merges.size).to eq(1)
      expect(merges[0].target_branch.author.name).to eq(DIFFERENT_NAME)
    end

    it 'can be looked up by user and repository' do
      merges = Merge.from_repository('repository_name').by_target_user(User.where(name: DIFFERENT_NAME).first)
      expect(merges.size).to eq(1)
      expect(merges[0].target_branch.author.name).to eq(DIFFERENT_NAME)
    end

    it 'can be filtered by status change date' do
      merges = Merge.created_after(2.minutes.from_now)
      expect(merges.size).to eq(0)

      merges = Merge.created_after(2.minutes.ago)
      expect(merges.size).to eq(2)
    end
  end

  context 'with branches from multiple repositories' do
    it 'returns branches from a repository' do
      @merge_1 = create_test_merge(@branches[0], @branches[1])
      @merge_2 = create_test_merge(
          create_test_branch(repository_name: 'repository_b', name: 'name_a'),
          create_test_branch(repository_name: 'repository_b', name: 'name_b'))

      merges = Merge.from_repository('repository_b').all
      expect(merges.size).to eq(1)
      expect(merges[0].id).to eq(@merge_2.id)
    end
  end

  context 'with successful and unsuccessful merges' do
    before do
      @merge_1 = create_test_merge(@branches[0], @branches[1], successful: true)
      @merge_2 = create_test_merge(@branches[0], @branches[2], successful: false)
    end

    it 'can be filtered by success' do
      expect(Merge.successful.size).to eq(1)
      expect(Merge.successful[0].id).to eq(@merge_1.id)
    end

    it 'can be filtered by failure' do
      expect(Merge.unsuccessful.size).to eq(1)
      expect(Merge.unsuccessful[0].id).to eq(@merge_2.id)
    end
  end
end

