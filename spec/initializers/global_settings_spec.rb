require 'spec_helper'

describe 'GlobalSettings' do
  include FakeFS::SpecHelpers

  before do
    FileUtils.mkdir_p("#{Rails.root}/config")
  end

  it 'uses default settings for all but required values' do
    yaml = "repositories_to_check:\n" +
           "  MyRepo:\n" +
           "    repository_name: 'Organization/repository'\n" +
           "    master_branch_name: 'master'\n"

    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)

    expected_settings = OpenStruct.new(DEFAULT_SETTINGS)
    expected_settings.repositories_to_check = {
        'MyRepo' => OpenStruct.new(
            DEFAULT_REPOSITORY_SETTINGS.merge({
            repository_name: 'Organization/repository',
            master_branch_name: 'master'
        }))}

    expect(load_global_settings).to eq(expected_settings)
  end

  it 'repositories_to_check is required (file empty)' do
    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", '')
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end

  it 'repositories_to_check is required (no file)' do
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end

  it 'repository_name is required' do
    yaml = "repositories_to_check:\n" +
           "  MyRepo:\n" +
           "    master_branch_name: 'master'\n"

    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end

  it 'master_branch_name is required' do
    yaml = "repositories_to_check:\n" +
           "  MyRepo:\n" +
           "    repository_name: 'Organization/repository'\n"

    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end
end