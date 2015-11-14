module Git
  class Conflict
    attr_reader :branch_a, :branch_b, :conflicting_files

    def initialize(branch_a, branch_b, conflicting_files)
      unless conflicting_files.present?
        raise ArgumentError.new("Must specify conflicting file list")
      end

      @branch_a = branch_a
      @branch_b = branch_b
      @conflicting_files = conflicting_files
    end
  end
end
