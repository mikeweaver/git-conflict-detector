module Git
  class GitBranch
    attr_reader :repository_name, :name, :last_modified_date, :author_name, :author_email

    def initialize(repository_name, name, last_modified_date, author_name, author_email)
      @repository_name = repository_name
      @name = name
      @last_modified_date = last_modified_date
      @author_email = author_email
      @author_name = author_name
    end

    def to_s
      name
    end

    def =~(rhs)
      name =~ rhs
    end

    def ==(rhs)
      repository_name == rhs.repository_name && name == rhs.name && last_modified_date == rhs.last_modified_date && author_email == rhs.author_email && author_name == rhs.author_name
    end
  end
end
