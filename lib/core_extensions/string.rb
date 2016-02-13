module CoreExtensions
  module String
    def escape_double_quotes
      gsub('"', '\\"')
    end

    def escape_double_quotes!
      gsub!('"', '\\"')
    end
  end
end
