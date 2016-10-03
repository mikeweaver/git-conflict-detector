module ErrorsJson
  extend ActiveSupport::Concern

  included do
    fields do
      errors_json :string, limit: 256, required: false
    end

    def errors
      @errors ||= JSON.parse(self.errors_json || '[]')
    end

    def errors=(error_list)
      if error_list.empty?
        self.errors_json = nil
      else
        self.errors_json = error_list.to_json
      end
    end
  end
end
