# Load application configuration
require 'ostruct'
require 'yaml'

def load_global_settings
  settings_hash = YAML.load_file("#{Rails.root}/config/settings.#{Rails.env}.yml") || {}

  # convert to open struct
  settings_object = OpenStruct.new(settings_hash)
  settings_object.repos_to_check.each do |repo_name, repo_settings|
    settings_object.repos_to_check[repo_name] = OpenStruct.new(repo_settings)
  end

  # cleanup data
  settings_object.email_override.downcase!
  settings_object.email_filter.collect! { |email| email.downcase }

  settings_object
end

GlobalSettings = load_global_settings

