# Load application configuration
require 'ostruct'
require 'yaml'

DEFAULT_SETTINGS = {
  cache_directory: './tmp/cache/git',
  maximum_branches_to_check: 0,
  email_override: '',
  email_filter: [],
  bcc_emails: [],
  email_from_address: 'gitconflictdetector@noreply.com',
  web_server_url: '',
  repositories_to_check_for_conflicts: {},
  branches_to_merge: {},
  dry_run: false
}.freeze

DEFAULT_BRANCH_FILTERS = {
  ignore_branches: [],
  ignore_branches_modified_days_ago: 0,
  only_branches: []
}.freeze

DEFAULT_REPOSITORY_SETTINGS = {
  repository_name: '',
  default_branch_name: ''
}.freeze

DEFAULT_CONFLICT_DETECTION_SETTINGS = {
  ignore_conflicts_in_file_paths: [],
  suppress_conflicts_for_owners_of_branches: []
}.merge(DEFAULT_BRANCH_FILTERS).merge(DEFAULT_REPOSITORY_SETTINGS).freeze

DEFAULT_AUTO_MERGE_SETTINGS = {
  source_branch_name: [],
  only_merge_source_branch_with_tag: ''
}.merge(DEFAULT_BRANCH_FILTERS).merge(DEFAULT_REPOSITORY_SETTINGS).freeze

class InvalidSettings < StandardError; end

def skip_validations
  ENV['VALIDATE_SETTINGS'] && ENV['VALIDATE_SETTINGS'].casecmp('false')
end

def validate_common_settings(settings)
  return if skip_validations

  unless settings.repositories_to_check_for_conflicts._?.any? \
         || settings.branches_to_merge._?.any?
    raise InvalidSettings,
          'Must specify at least one repository to check for conflicts or one branch to merge'
  end

  if settings.web_server_url.blank?
    raise InvalidSettings, 'Must specify the web server URL'
  end
end

def validate_repository_settings(name, settings)
  return if skip_validations

  if settings.repository_name.blank?
    raise InvalidSettings, "Must specify repository name for #{name}"
  end
  if settings.default_branch_name.blank?
    raise InvalidSettings, "Must specify default branch name for #{name}"
  end
end

def load_global_settings
  settings_path = "#{Rails.root}/data/config/settings.#{Rails.env}.yml"
  settings_hash = if File.exist?(settings_path)
                    YAML.load_file(settings_path) || {}
                  else
                    {}
                  end

  unless settings_hash.is_a?(Hash)
    raise InvalidSettings, 'Settings file is not a hash'
  end

  # convert to open struct
  settings_object = OpenStruct.new(DEFAULT_SETTINGS.merge(settings_hash))

  validate_common_settings(settings_object)

  # convert nested conflict hashes to open struct and validate them
  settings_object.repositories_to_check_for_conflicts._?.each do |repository_name, repository_settings|
    conflict_settings = OpenStruct.new(DEFAULT_CONFLICT_DETECTION_SETTINGS.merge(repository_settings))
    validate_repository_settings(repository_name, conflict_settings)
    settings_object.repositories_to_check_for_conflicts[repository_name] = conflict_settings
  end

  settings_object.branches_to_merge._?.each do |branch_name, repository_settings|
    auto_merge_settings = OpenStruct.new(DEFAULT_AUTO_MERGE_SETTINGS.merge(repository_settings))
    validate_repository_settings(branch_name, auto_merge_settings)
    if auto_merge_settings.source_branch_name.blank?
      raise InvalidSettings, "Must specify auto-merge source branch name for #{branch_name}"
    end
    settings_object.branches_to_merge[branch_name] = auto_merge_settings
  end

  # cleanup data
  settings_object.email_override.downcase!
  settings_object.email_filter.collect!(&:downcase)

  settings_object
end

GlobalSettings = load_global_settings
