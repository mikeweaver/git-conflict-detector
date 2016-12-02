require 'spec_helper'

describe 'GlobalSettings' do
  include FakeFS::SpecHelpers

  before do
    FileUtils.mkdir_p("#{Rails.root}/data/config")
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required (file empty)' do
    File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", '')
    expect { load_global_settings }.to raise_exception(InvalidSettings, /repository.*merge/)
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required (no file)' do
    expect { load_global_settings }.to raise_exception(InvalidSettings, /repository.*merge/)
  end

  it 'repositories_to_check_for_conflicts or branches_to_merge are required (empty hashes)' do
    invalid_settings = {
      repositories_to_check_for_conflicts: nil,
      branches_to_merge: nil
    }
    File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", invalid_settings.to_yaml)
    puts invalid_settings.to_yaml
    expect { load_global_settings }.to raise_exception(InvalidSettings, /repository.*merge/)
  end

  it 'skips all validations if VALIDATE_SETTINGS is false' do
    stub_env('VALIDATE_SETTINGS', 'false')
    # no file
    load_global_settings
    expect(load_global_settings).to eq(OpenStruct.new(DEFAULT_SETTINGS))

    # empty file
    File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", '')
    load_global_settings
    expect(load_global_settings).to eq(OpenStruct.new(DEFAULT_SETTINGS))

    # invalid file
    invalid_settings = {
      ignore_me: {
        'key' => 'value'
      }
    }
    File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", invalid_settings.to_yaml)
    load_global_settings
    expect(load_global_settings).to eq(OpenStruct.new(DEFAULT_SETTINGS.merge(invalid_settings)))
  end

  context 'with repositories_to_check_for_conflicts' do
    before do
      @required_settings = DEFAULT_SETTINGS.merge(
        'web_server_url' => 'http://myserver.com',
        'repositories_to_check_for_conflicts' => {
          'MyRepo' => DEFAULT_CONFLICT_DETECTION_SETTINGS.merge(
            'repository_name' => 'Organization/repository',
            'default_branch_name' => 'master'
          )
        }
      )
    end

    it 'uses default settings for all but required values' do
      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)

      expected_settings = OpenStruct.new(@required_settings)
      expected_settings.repositories_to_check_for_conflicts['MyRepo'] = \
        OpenStruct.new(@required_settings['repositories_to_check_for_conflicts']['MyRepo'])

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      @required_settings['repositories_to_check_for_conflicts']['MyRepo'].except!('repository_name')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /repository name/)
    end

    it 'default_branch_name is required' do
      @required_settings['repositories_to_check_for_conflicts']['MyRepo'].except!('default_branch_name')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /default branch/)
    end

    it 'web_server_url is required' do
      @required_settings.except!('web_server_url')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /web server/)
    end
  end

  context 'with branches_to_merge' do
    before do
      @required_settings = DEFAULT_SETTINGS.merge(
        'web_server_url' => 'http://myserver.com',
        'branches_to_merge' => {
          'MyRepo-branch' => DEFAULT_AUTO_MERGE_SETTINGS.merge(
            'repository_name' => 'Organization/repository',
            'default_branch_name' => 'master',
            'source_branch_name' => 'source'
          )
        }
      )
    end

    it 'uses default settings for all but required values' do
      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)

      expected_settings = OpenStruct.new(@required_settings)
      expected_settings.branches_to_merge['MyRepo-branch'] = \
        OpenStruct.new(@required_settings['branches_to_merge']['MyRepo-branch'])

      expect(load_global_settings).to eq(expected_settings)
    end

    it 'repository_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('repository_name')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /repository name/)
    end

    it 'default_branch_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('default_branch_name')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /default branch/)
    end

    it 'source_branch_name is required' do
      @required_settings['branches_to_merge']['MyRepo-branch'].except!('source_branch_name')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /source branch/)
    end

    it 'web_server_url is required' do
      @required_settings.except!('web_server_url')

      File.write("#{Rails.root}/data/config/settings.#{Rails.env}.yml", @required_settings.to_yaml)
      expect { load_global_settings }.to raise_exception(InvalidSettings, /web server/)
    end
  end
end
