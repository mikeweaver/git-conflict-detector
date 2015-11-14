module Git
  class GitConflict
    attr_reader :branch_a, :branch_b, :conflicting_files

    def initialize(branch_a, branch_b, conflicting_files)
      unless conflicting_files.present?
        raise ArgumentError.new("Must specify conflicting file list")
      end

      @branch_a = branch_a
      @branch_b = branch_b
      @conflicting_files = conflicting_files
    end

    def ==(rhs)
      @branch_a == rhs.branch_a && @branch_b == rhs.branch_b && @conflicting_files == rhs.conflicting_files
    end

    def contains_branch(branch_name)
      @branch_a == branch_name || @branch_b == branch_name
    end
  end
end
