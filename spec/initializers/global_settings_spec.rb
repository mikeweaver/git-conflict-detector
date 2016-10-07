require 'spec_helper'

describe 'GlobalSettings' do
  include FakeFS::SpecHelpers

  before do
    FileUtils.mkdir_p("#{Rails.root}/config")
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required or jira (file empty)' do
    File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", '')
    expect { load_global_settings }.to raise_exception(InvalidSettings, /repository.*merge.*jira/)
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required or jira (no file)' do
    expect { load_global_settings }.to raise_exception(InvalidSettings, /repository.*merge.*jira/)
  end

  context 'with repositories_to_check_for_conflicts' do
    before do
      @required_settings = DEFAULT_SETTINGS.merge(
          {'web_server_url' => 'http://myserver.com',
           'repositories_to_check_for_conflicts' => {
               'MyRepo' => DEFAULT_CONFLICT_DETECTION_SETTINGS.merge(
                   {'repository_name' => 'Organization/repository',
                    'default_branch_name' => 'master'})}})
    end

    it 'uses default settings for all but required values' do
      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)

      expected_settings = OpenStruct.new(@required_settings)
      expected_settings.repositories_to_check_for_conflicts['MyRepo'] = OpenStruct.new(@required_settings['repositories_to_check_for_conflicts']['MyRepo'])

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      @required_settings['repositories_to_check_for_conflicts']['MyRepo'].except!('repository_name')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /repository name/)
    end

    it 'default_branch_name is required' do
      @required_settings['repositories_to_check_for_conflicts']['MyRepo'].except!('default_branch_name')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /default branch/)
    end

    it 'web_server_url is required' do
      @required_settings.except!('web_server_url')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /web server/)
    end
  end

  context 'with branches_to_merge' do
    before do
      @required_settings = DEFAULT_SETTINGS.merge(
          {'web_server_url' => 'http://myserver.com',
           'branches_to_merge' => {
               'MyRepo-branch' => DEFAULT_AUTO_MERGE_SETTINGS.merge(
               {'repository_name' => 'Organization/repository',
                'default_branch_name' => 'master',
                'source_branch_name' => 'source'})}})
    end

    it 'uses default settings for all but required values' do
      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)

      expected_settings = OpenStruct.new(@required_settings)
      expected_settings.branches_to_merge['MyRepo-branch'] = OpenStruct.new(@required_settings['branches_to_merge']['MyRepo-branch'])

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('repository_name')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /repository name/)
    end

    it 'default_branch_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('default_branch_name')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /default branch/)
    end

    it 'source_branch_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('source_branch_name')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /source branch/)
    end

    it 'web_server_url is required' do
      @required_settings.except!('web_server_url')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /web server/)
    end
  end

  context 'with jira' do
    before do
      @required_settings = DEFAULT_SETTINGS.merge(
          {'web_server_url' => 'http://myserver.com',
           'jira' => DEFAULT_JIRA_SETTINGS.merge(
               {'site' => 'https://test.atlassian.net',
                'consumer_key' => 'test_consumer_key',
                'access_token' => 'test_access_token',
                'access_key' => 'test_access_key',
                'ancestor_branches' => { 'default' => 'master' },
                'project_keys' => ['STORY'],
                'valid_statuses' => ['Ready to Deploy']})})
    end

    it 'uses default settings for all but required values' do
      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)

      expected_settings = OpenStruct.new(@required_settings)
      expected_settings.jira = OpenStruct.new(@required_settings['jira'])

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'site is required' do
      @required_settings['jira'].except!('site')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /site/)
    end

    it 'consumer_key is required' do
      @required_settings['jira'].except!('consumer_key')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /consumer/)
    end

    it 'access_token is required' do
      @required_settings['jira'].except!('access_token')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /access token/)
    end

    it 'access_key is required' do
      @required_settings['jira'].except!('access_key')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /access key/)
    end

    it 'ancestor_branches is required' do
      @required_settings['jira'].except!('ancestor_branches')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /ancestor/)
    end

    it 'project_keys is required' do
      @required_settings['jira'].except!('project_keys')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /project/)
    end

    it 'valid_statuses is required' do
      @required_settings['jira'].except!('valid_statuses')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /status/)
    end

    it 'web_server_url is required' do
      @required_settings.except!('web_server_url')

      File.write("#{Rails.root}/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /web server/)
    end
  end
end
