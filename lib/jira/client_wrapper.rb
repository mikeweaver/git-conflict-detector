require 'jira'

module JIRA
  class ClientWrapper < JIRA::Client
    def initialize(settings)
      client_options = {
          signature_method: 'RSA-SHA1',
          consumer_key: settings.consumer_key,
          site: settings.site,
          context_path: '',
          use_ssl: true,
          private_key_file: settings.private_key_file
      }

      super(client_options)

      @request_client.set_access_token(settings.access_token, settings.access_key)

      consumer.http.set_debug_output($stderr)
    end

    def find_issue(key)
      self.Issue.find(key)
    rescue JIRA::HTTPError => ex
      if ex.response.code == "404"
        nil
      else
        raise
      end
    end
  end
end

