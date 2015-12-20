module Git
  class GitConflict
    attr_reader :repository_name, :branch_a, :branch_b, :conflicting_files

    def initialize(repository_name, branch_a, branch_b, conflicting_files)
      unless conflicting_files.present?
        raise ArgumentError.new("Must specify conflicting file list")
      end

      @repository_name = repository_name
      @branch_a = branch_a
      @branch_b = branch_b
      @conflicting_files = conflicting_files
    end

    def ==(rhs)
      @repository_name == rhs.repository_name && @branch_a == rhs.branch_a && @branch_b == rhs.branch_b && @conflicting_files == rhs.conflicting_files
    end

    def contains_branch(branch_name)
      @branch_a == branch_name || @branch_b == branch_name
    end
  end
end
