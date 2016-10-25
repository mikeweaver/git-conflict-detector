require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GitConflictDetector
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # SMTP settings
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              Rails.application.secrets.smtp_address,
      port:                 587,
      user_name:            Rails.application.secrets.smtp_user_name,
      password:             Rails.application.secrets.smtp_password,
      authentication:       'plain',
      enable_starttls_auto: true
    }

    config.autoload_paths += Dir["#{config.root}/lib/**/"]

    config.exceptions_app = routes

    config.after_initialize do
      # TODO: Cleanup the creation of the GlobalSettings global variable
      # It currently relies on this line being the first time the application references it
      # Earlier references could cause the validation to fail because the ENV is not loaded yet
      Rails.application.routes.default_url_options[:host] = GlobalSettings.web_server_url

      # disable logging of SQL statements
      ActiveRecord::Base.logger = nil

      # make the cache folder
      FileUtils.mkdir_p(GlobalSettings.cache_directory)
    end

    config.active_job.queue_adapter = :delayed_job
  end
end
