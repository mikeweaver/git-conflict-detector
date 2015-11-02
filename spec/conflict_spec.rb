require 'spec_helper'

describe 'Conflict' do

  before do
    @branches = []
    (0..2).each do |i|
      git_data = Git::Branch.new(
          "path/branch#{i}",
          DateTime.now,
          'Author Name',
          'author@email.com')
      @branches << Branch.create_from_git_data(git_data)
    end
  end

  it 'can be created' do
    tested_at = Time.now()
    Conflict.create!(@branches[0], @branches[1], tested_at)

    expect(Conflict.all.size).to eq(1)
  end

  it 're-creating updates last_tested_date' do
    tested_at1 = Time.now()
    Conflict.create!(@branches[0], @branches[1], tested_at1)
    tested_at2 = Time.now()
    Conflict.create!(@branches[0], @branches[1], tested_at2)

    expect(tested_at1).not_to eq(tested_at2)
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.last_tested_date).to eq(tested_at2)
  end

  it 'can be cleared' do
    Conflict.create!(@branches[0], @branches[1], Time.now())
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.resolved).to be_falsey
    Conflict.clear!(@branches[0], @branches[1], Time.now())
    expect(Conflict.all.size).to eq(1)
    expect(Conflict.first.resolved).to be_truthy
  end

  it 'does not raise an error when clearing a non-existent conflict' do
    Conflict.clear!(@branches[0], @branches[1], Time.now())
  end

  it 'does not care about branch order' do
    Conflict.create!(@branches[0], @branches[1], Time.now())
    Conflict.create!(@branches[1], @branches[0], Time.now())
    expect(Conflict.all.size).to eq(1)
  end

  it 'treats different branch combinations as unique' do
    Conflict.create!(@branches[0], @branches[1], Time.now())
    Conflict.create!(@branches[1], @branches[2], Time.now())
    Conflict.create!(@branches[0], @branches[2], Time.now())
    expect(Conflict.all.size).to eq(3)
  end

  it 'cannot conflict with itself' do
    expect { Conflict.create!(@branches[0], @branches[0], Time.now()) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'requires two branches' do
    expect { Conflict.create!(@branches[0], nil, Time.now()) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { Conflict.create!(nil, @branches[0], Time.now()) }.to raise_exception(ActiveRecord::RecordInvalid)
    expect { Conflict.create!(nil, nil, Time.now()) }.to raise_exception(ActiveRecord::RecordInvalid)
  end

  it 'does not allow duplicate conflicts' do
    Conflict.create!(@branches[0], @branches[1], Time.now())
    conflict = Conflict.new
    conflict.branch_a = @branches[0]
    conflict.branch_b = @branches[1]
    conflict.last_tested_date = Time.now()
    expect { conflict.save! }.to raise_exception
  end

end

