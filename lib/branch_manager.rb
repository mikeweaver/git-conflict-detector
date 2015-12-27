class BranchManager

  def initialize(settings)
    @settings = settings
    @git = Git::Git.new(@settings.repository_name)
  end

  protected

  def update_branch_list!
    # note when we started so we can tell which branches in our DB have/have not been updated
    # by the data we got from git
    start_time = Time.now

    # make sure we have the latest copy of the repository
    @git.clone_repository(@settings.master_branch_name)

    # get a list of branches and add them to the DB
    get_branch_list.each do |branch|
      raise "Branch repository name #{branch.repository_name} does not match settings respository name #{@settings.repository_name}" if @settings.repository_name != branch.repository_name
      Branch.create_from_git_data!(branch)
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.from_repository(@settings.repository_name).branches_not_updated_since(start_time).destroy_all
  end

  private

  def should_ignore_branch_by_list?(branch)
    @settings.ignore_branches.include_regex?(branch)
  end

  def should_ignore_branch_by_date?(branch)
    @settings.ignore_branches_modified_days_ago > 0 or return
    branch.last_modified_date < (Time.now - @settings.ignore_branches_modified_days_ago.days)
  end

  def should_include_branch?(branch)
    !@settings.only_branches.empty? or return true
    @settings.only_branches.include_regex?(branch)
  end

  def should_ignore_conflicts?(conflicts)
    @settings.ignore_conflicts_in_file_paths or return false
    conflicts.reject_regex(@settings.ignore_conflicts_in_file_paths).empty?
  end

  def get_branch_list
    branches = @git.get_branch_list

    branches.delete_if do |branch|
      if should_ignore_branch_by_list?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is on the ignore list")
        true
      elsif !should_include_branch?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is not on the include list")
        true
      elsif should_ignore_branch_by_date?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it has not been modified in over #{@settings.ignore_branches_modified_days_ago} days")
        true
      else
        false
      end
    end
  end

end

