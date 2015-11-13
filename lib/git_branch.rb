module Git
  class Branch
    attr_reader :name, :last_modified_date, :author_name, :author_email

    def initialize(name, last_modified_date, author_name, author_email)
      @name = name
      @last_modified_date = last_modified_date
      @author_email = author_email
      @author_name = author_name
    end

    def to_s
      @name
    end

    def =~(rhs)
      @name =~ rhs
    end
  end
end
