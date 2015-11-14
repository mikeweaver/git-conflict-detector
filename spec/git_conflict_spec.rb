require 'spec_helper'

describe 'GitConflict' do

  it 'can be created' do
    conflict = Git::Conflict.new('branch_a', 'branch_b', ['file1', 'file2'])

    expect(conflict.branch_a).to eq('branch_a')
    expect(conflict.branch_b).to eq('branch_b')
    expect(conflict.conflicting_files).to eq(['file1', 'file2'])
  end

  it 'cannot be created with conflicting files' do
    expect { Git::Conflict.new('branch_a', 'branch_b', nil) }.to raise_exception(ArgumentError)
    expect { Git::Conflict.new('branch_a', 'branch_b', []) }.to raise_exception(ArgumentError)
  end
end
