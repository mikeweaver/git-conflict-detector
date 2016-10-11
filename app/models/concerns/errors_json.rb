module ErrorsJson
  extend ActiveSupport::Concern

  included do
    fields do
      errors_json :string, limit: 256, required: false
      ignore_errors :boolean, default: false, required: true
    end

    scope :with_errors, lambda { where("errors_json IS NOT NULL AND errors_json <> '[]'") }
    scope :with_unignored_errors, lambda { with_errors.where(ignore_errors: false) }

    def error_list
      @error_list ||= JSON.parse(self.errors_json || '[]').uniq
    end

    def error_list=(list)
      unless error_list.to_set == list.to_set
        self.errors_json = list.uniq.to_json
        @error_list = nil
        # clear the ignore_errors flag when the errors change
        self.ignore_errors = false
      end
    end

    def self.get_error_counts(error_json_objects)
      error_counts = {}
      error_json_objects.each do |error_json_object|
        error_json_object.error_list.each do |error|
          error_counts[error] = error_counts[error].to_i + 1
        end
      end
      error_counts
    end

    def reload
      super
      # clear memoized data on reload
      @error_list = nil
    end

    def has_errors?
      error_list.any?
    end

    def has_unignored_errors?
      has_errors? && !ignore_errors
    end

    def has_ignored_errors?
      has_errors? && ignore_errors
    end

    def has_error?(error)
      error_list.include?(error)
    end
  end
end
