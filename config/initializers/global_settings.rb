# Load application configuration
require 'ostruct'
require 'yaml'

DEFAULT_SETTINGS = {
  cache_directory: './tmp/cache/git',
  maximum_branches_to_check: 0,
  email_override: '',
  email_filter: [],
  bcc_emails: [],
  web_server_url: '',
  repositories_to_check: {}
}

DEFAULT_REPOSITORY_SETTINGS = {
  repository_name: '',
  ignore_branches: [],
  ignore_branches_modified_days_ago: 0,
  only_branches: [],
  ignore_conflicts_in_file_paths: [],
  master_branch_name: '',
  suppress_conflicts_for_owners_of_branches: [],
  push_successful_merges_of: {}
}

class InvalidSettings < StandardError; end


def load_global_settings
  settings_path = "#{Rails.root}/config/settings.#{Rails.env}.yml"
  settings_hash = if File.exists?(settings_path)
     YAML.load_file(settings_path) || {}
  else
    {}
  end

  unless settings_hash.is_a?(Hash)
    raise InvalidSettings.new('Settings file is not a hash')
  end

  # convert to open struct
  settings_object = OpenStruct.new(DEFAULT_SETTINGS.merge(settings_hash))
  settings_object.repositories_to_check.each do |repository_name, repository_settings|
    settings_object.repositories_to_check[repository_name] = OpenStruct.new(DEFAULT_REPOSITORY_SETTINGS.merge(repository_settings))
    if settings_object.repositories_to_check[repository_name].repository_name.blank?
      raise InvalidSettings.new("Must specify repository name for repository #{repository_name}")
    end
    if settings_object.repositories_to_check[repository_name].master_branch_name.blank?
      raise InvalidSettings.new("Must specify master branch name for repository #{repository_name}")
    end
  end

  # validate required args are present
  if settings_object.repositories_to_check.empty?
    raise InvalidSettings.new('Must specify at least one repository to check')
  end

  # cleanup data
  settings_object.email_override.downcase!
  settings_object.email_filter.collect! { |email| email.downcase }

  settings_object
end

GlobalSettings = load_global_settings

