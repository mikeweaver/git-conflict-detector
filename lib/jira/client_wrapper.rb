require 'jira'

module JIRA
  class ClientWrapper < JIRA::Client
    def initialize(settings)
      client_options = {
          signature_method: 'RSA-SHA1',
          consumer_key: settings.consumer_key,
          site: settings.site,
          context_path: "",
          use_ssl: true
      }

      super(client_options)

      @request_client.set_access_token(settings.access_token, settings.access_key)

      consumer.http.set_debug_output($stderr)
    end

    def find_issue(key)
      self.Issue.find(key)
    rescue JIRA::HTTPError => ex
      puts ex.response
      puts '****'
      if ex.message == 'Not Found'
        nil
      else
        raise
      end
    end
  end
end

