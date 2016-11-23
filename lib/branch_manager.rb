class BranchManager
  def initialize(settings)
    @settings = settings
    @git = Git::Git.new(@settings.repository_name, git_cache_path: GlobalSettings.cache_directory)
  end

  protected

  def update_branch_list!
    # note when we started so we can tell which branches in our DB have/have not been updated
    # by the data we got from git
    start_time = Time.current

    # make sure we have the latest copy of the repository
    @git.clone_repository(@settings.default_branch_name)

    # get a list of branches and add them to the DB
    @git.branch_list.each do |branch|
      if @settings.repository_name == branch.repository_name
        Branch.create_from_git_data!(branch)
      else
        raise "Branch repository name #{branch.respository_name} does not match " \
              "settings repository name #{@settings.repository_name}"
      end
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.from_repository(@settings.repository_name).branches_not_updated_since(start_time).destroy_all
  end

  def filter_branch_list(branches)
    branches.to_a.delete_if do |branch|
      if should_ignore_branch_by_list?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is on the ignore list")
        true
      elsif !should_include_branch?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is not on the include list")
        true
      elsif should_ignore_branch_by_date?(branch)
        Rails.logger.info(
          "Skipping branch #{branch.name}, it has not been modified in over " \
          "#{@settings.ignore_branches_modified_days_ago} days"
        )
        true
      else
        false
      end
    end
  end

  private

  def should_ignore_branch_by_list?(branch)
    @settings.ignore_branches.include_regexp?(branch)
  end

  def should_ignore_branch_by_date?(branch)
    @settings.ignore_branches_modified_days_ago > 0 || return
    branch.git_updated_at < (Time.current - @settings.ignore_branches_modified_days_ago.days)
  end

  def should_include_branch?(branch)
    !@settings.only_branches.empty? || (return true)
    @settings.only_branches.include_regexp?(branch)
  end
end
