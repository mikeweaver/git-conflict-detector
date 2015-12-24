module CoreExtensions
  module Array
    def include_regex?(object)
      any? do |regex_string_or_object|
        # convert objects in array to regex if needed
        regex = if regex_string_or_object.is_a?(Regexp)
          regex_string_or_object
        else
          Regexp.new(regex_string_or_object)
        end
        (object =~ regex) != nil
      end
    end

    def reject_regex(regex_or_regex_array)
      if regex_or_regex_array.is_a?(Array)
        reject do |object|
          regex_or_regex_array.include_regex?(object)
        end
      else
        reject do |object|
          (object =~ regex_or_regex_array) != nil
        end
      end
    end

    def select_regex(regex_or_regex_array)
      if regex_or_regex_array.is_a?(Array)
        select do |object|
          regex_or_regex_array.include_regex?(object)
        end
      else
        select do |object|
          (object =~ regex_or_regex_array) != nil
        end
      end
    end
  end
end
