require 'spec_helper'

describe 'GitBranch' do

  it 'can be created' do
    last_modified_date = Time.now
    branch = Git::GitBranch.new('repository_name', 'name', last_modified_date , 'author_name', 'author@email.com')

    expect(branch.repository_name).to eq('repository_name')
    expect(branch.name).to eq('name')
    expect(branch.last_modified_date).to eq(last_modified_date)
    expect(branch.author_name).to eq('author_name')
    expect(branch.author_email).to eq('author@email.com')
  end

  it 'implements regex operator' do
    branch = Git::GitBranch.new('repository_name', 'verylongname', Time.now , 'author_name', 'author@email.com')

    expect(branch =~ /.*long.*/).to be_truthy
    expect(branch =~ /nomatch/).to be_falsey
  end

  it 'implements equality operator' do
    last_modified_date = Time.now
    branch_a = Git::GitBranch.new('repository_name', 'name', last_modified_date , 'author_name', 'author@email.com')

    branch_b = Git::GitBranch.new('repository_name', 'name', last_modified_date , 'author_name', 'author@email.com')
    expect(branch_a).to eq(branch_b)

    branch_c = Git::GitBranch.new('different', 'name', last_modified_date , 'author_name', 'author@email.com')
    expect(branch_a).not_to eq(branch_c)

    branch_d = Git::GitBranch.new('repository_name', 'different', last_modified_date , 'author_name', 'author@email.com')
    expect(branch_a).not_to eq(branch_d)

    branch_e = Git::GitBranch.new('repository_name', 'name', Time.now , 'author_name', 'author@email.com')
    expect(branch_a).not_to eq(branch_e)

    branch_f = Git::GitBranch.new('repository_name', 'name', last_modified_date , 'different', 'author@email.com')
    expect(branch_a).not_to eq(branch_f)

    branch_g = Git::GitBranch.new('repository_name', 'name', last_modified_date , 'author_name', 'different@email.com')
    expect(branch_a).not_to eq(branch_g)
  end
end
