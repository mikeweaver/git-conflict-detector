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
  repositories_to_check_for_conflicts: {},
  branches_to_merge: {},
  dry_run: false
}

DEFAULT_BRANCH_FILTERS = {
  ignore_branches: [],
  ignore_branches_modified_days_ago: 0,
  only_branches: []
}

DEFAULT_REPOSITORY_SETTINGS = {
  repository_name: '',
  default_branch_name: ''
}

DEFAULT_CONFLICT_DETECTION_SETTINGS = {
  ignore_conflicts_in_file_paths: [],
  suppress_conflicts_for_owners_of_branches: []
}.merge(DEFAULT_BRANCH_FILTERS).merge(DEFAULT_REPOSITORY_SETTINGS)

DEFAULT_AUTO_MERGE_SETTINGS = {
    source_branch_name: []
}.merge(DEFAULT_BRANCH_FILTERS).merge(DEFAULT_REPOSITORY_SETTINGS)

class InvalidSettings < StandardError; end


def validate_repository_settings(name, settings)
  if settings.repository_name.blank?
    raise InvalidSettings.new("Must specify repository name for #{name}")
  end
  if settings.default_branch_name.blank?
    raise InvalidSettings.new("Must specify default branch name for #{name}")
  end
end

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

  # validate required args are present
  if settings_object.repositories_to_check_for_conflicts.empty? && settings_object.branches_to_merge.empty?
    raise InvalidSettings.new('Must specify at least one repository to check for conflicts or one branch to merge')
  end

  # convert nested conflict hashes to open struct and validate them
  settings_object.repositories_to_check_for_conflicts.each do |repository_name, repository_settings|
    conflict_settings = OpenStruct.new(DEFAULT_CONFLICT_DETECTION_SETTINGS.merge(repository_settings))
    validate_repository_settings(repository_name, conflict_settings)
    settings_object.repositories_to_check_for_conflicts[repository_name] = conflict_settings
  end

  settings_object.branches_to_merge.each do |branch_name, repository_settings|
    auto_merge_settings = OpenStruct.new(DEFAULT_AUTO_MERGE_SETTINGS.merge(repository_settings))
    validate_repository_settings(branch_name, auto_merge_settings)
    if auto_merge_settings.source_branch_name.blank?
      raise InvalidSettings.new("Must specify auto-merge source branch name for #{branch_name}")
    end
    settings_object.branches_to_merge[branch_name] = auto_merge_settings
  end

  # cleanup data
  settings_object.email_override.downcase!
  settings_object.email_filter.collect! { |email| email.downcase }

  settings_object
end

GlobalSettings = load_global_settings

