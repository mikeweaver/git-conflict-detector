require 'spec_helper'

describe 'GlobalSettings' do
  include FakeFS::SpecHelpers

  before do
    FileUtils.mkdir_p("#{Rails.root}/config")
  end


  it 'repositories_to_check_for_conflicts or branches_to_merge are required (file empty)' do
    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", '')
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required (no file)' do
    expect { load_global_settings }.to raise_exception(InvalidSettings)
  end

  context 'with repositories_to_check_for_conflicts' do
    it 'uses default settings for all but required values' do
      yaml = "repositories_to_check_for_conflicts:\n" +
             "  MyRepo:\n" +
             "    repository_name: 'Organization/repository'\n" +
             "    default_branch_name: 'master'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)

      expected_settings = OpenStruct.new(DEFAULT_SETTINGS)
      expected_settings.repositories_to_check_for_conflicts = {
          'MyRepo' => OpenStruct.new(
              DEFAULT_CONFLICT_DETECTION_SETTINGS.merge({
                  repository_name: 'Organization/repository',
                  default_branch_name: 'master'}))}
      expected_settings.jira = OpenStruct.new(DEFAULT_JIRA_SETTINGS)

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      yaml = "repositories_to_check_for_conflicts:\n" +
             "  MyRepo:\n" +
             "    default_branch_name: 'master'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings)
    end

    it 'default_branch_name is required' do
      yaml = "repositories_to_check_for_conflicts:\n" +
             "  MyRepo:\n" +
             "    repository_name: 'Organization/repository'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings)
    end
  end

  context 'with branches_to_merge' do
    it 'uses default settings for all but required values' do
      yaml = "branches_to_merge:\n" +
             "  MyRepo-branch:\n" +
             "    repository_name: 'Organization/repository'\n" +
             "    default_branch_name: 'master'\n" +
             "    source_branch_name:  'source'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)

      expected_settings = OpenStruct.new(DEFAULT_SETTINGS)
      expected_settings.branches_to_merge = {
          'MyRepo-branch' => OpenStruct.new(
              DEFAULT_AUTO_MERGE_SETTINGS.merge({
                  repository_name: 'Organization/repository',
                  default_branch_name: 'master',
                  source_branch_name: 'source'}))}
      expected_settings.jira = OpenStruct.new(DEFAULT_JIRA_SETTINGS)

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      yaml = "branches_to_merge:\n" +
             "  MyRepo-branch:\n" +
             "    default_branch_name: 'master'\n" +
             "    source_branch_name:  'source'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings)
    end

    it 'default_branch_name is required' do
      yaml = "branches_to_merge:\n" +
             "  MyRepo-branch:\n" +
             "    repository_name: 'Organization/repository'\n" +
             "    source_branch_name:  'source'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings)
    end

    it 'source_branch_name is required' do
      yaml = "branches_to_merge:\n" +
             "  MyRepo-branch:\n" +
             "    repository_name: 'Organization/repository'\n" +
             "    default_branch_name:  'master'\n"

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings)
    end
  end

  # TODO Add JIRA settings tests
end
