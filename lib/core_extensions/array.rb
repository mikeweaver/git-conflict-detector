module CoreExtensions
  module Array
    def include_regex?(object, regexp_options=nil)
      any? do |regex_string_or_object|
        # convert objects in array to regex if needed
        regex = if regex_string_or_object.is_a?(Regexp)
          regex_string_or_object
        else
          Regexp.new(regex_string_or_object, regexp_options)
        end
        # compare with nil to force a boolean return type
        (object =~ regex) != nil
      end
    end

    def reject_regex(regex_or_regex_array, regexp_options=nil)
      if regex_or_regex_array.is_a?(Array)
        reject do |object|
          regex_or_regex_array.include_regex?(object, regexp_options)
        end
      else
        reject do |object|
          object =~ regex_or_regex_array
        end
      end
    end

    def select_regex(regex_or_regex_array, regexp_options=nil)
      if regex_or_regex_array.is_a?(Array)
        select do |object|
          regex_or_regex_array.include_regex?(object, regexp_options)
        end
      else
        select do |object|
          object =~ regex_or_regex_array
        end
      end
    end
  end
end
