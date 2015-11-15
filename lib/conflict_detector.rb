require 'yaml'
require 'fileutils'

class ConflictDetector

  def initialize(settings)
    @settings = settings
  end

  def run
    process_repo(@settings[:repo_name])
  end

  private

  def call_git(git, command, run_in_repo_path=true)
    Rails.logger.debug("Cmd: git #{command}")
    git.execute(command, run_in_repo_path)
  end

  def should_ignore_branch_by_list?(branch)
    @settings[:ignore_branches].any? do |regex|
      branch =~ Regexp.new(regex)
    end
  end

  def should_ignore_branch_by_date?(branch)
    branch.last_modified_date < (Date.today - @settings[:ignore_branches_modified_days_ago])
  end

  def should_include_branch?(branch)
    @settings[:only_branches] or return true

    @settings[:only_branches].any? do |regex|
      branch =~ Regexp.new(regex)
    end
  end

  def should_ignore_conflicts?(conflicts)
    conflicts.all? do |conflict|
      @settings[:ignore_conflicts_in_file_paths].any? do |regex|
        conflict =~ Regexp.new(regex)
      end
    end
  end

  def setup_repo(git)
    if Dir.exists?("#{git.repo_path}")
      # cleanup any changes that might have been left over if we crashed while running
      call_git(git, 'reset --hard origin')
      call_git(git, 'clean -f -d')

      # move to the master branch
      call_git(git, "checkout #{@settings[:master_branch_name]}")

      # remove branches that no longer exist on origin and update all branches that do
      call_git(git, 'fetch --prune --all')

      # pull all of the branches
      call_git(git, 'pull --all')
    else
      call_git(git, "clone #{git.repo_url} #{git.repo_path}", false)
    end
  end

  def get_branch_list(git)
    branches = git.get_branch_list

    branches.delete_if do |branch|
      if should_ignore_branch_by_list?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is on the ignore list")
        true
      elsif !should_include_branch?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it is not on the include list")
        true
      elsif should_ignore_branch_by_date?(branch)
        Rails.logger.info("Skipping branch #{branch.name}, it has not been modified in over #{@settings[:ignore_branches_modified_days_ago]} days")
        true
      else
        false
      end
    end
  end

  def get_conflicts(git, target_branch, source_branches)
    # get onto the target branch
    git.execute("checkout #{target_branch.name}")
    git.execute("reset --hard origin/#{target_branch.name}")

    conflicts = []
    branches_checked = 0
    source_branches.each do |source_branch|
      # break if we have tested enough branches already
      branches_checked += 1
      if @settings[:maximum_branches_to_check] && (branches_checked > @settings[:maximum_branches_to_check])
        Rails.logger.warn("WARNING: Checked the maximum number of branches allowed, #{@settings[:maximum_branches_to_check]}, exiting early")
        break
      end

      # don't try to merge the branch with itself
      next if target_branch.name == source_branch.name

      Rails.logger.debug("Attempt to merge #{source_branch.name}")
      conflict = git.detect_conflicts(target_branch.name, source_branch.name)
      unless conflict.present?
        Rails.logger.info("MERGED: #{source_branch.name} can be merged into #{target_branch.name} without conflicts")
      else
        if should_ignore_conflicts?(conflict.conflicting_files)
          Rails.logger.info("MERGED: #{target_branch.name} conflicts with #{source_branch.name}, but all conflicting files are on the ignore list.")
        else
          Rails.logger.info("CONFLICT: #{target_branch.name} conflicts with #{source_branch.name}\nConflicting files:\n#{conflict.conflicting_files}")
          conflicts << conflict
        end
      end
    end

    conflicts
  end

  def send_conflict_emails(repo_name, conflicts_newer_than)
    # only email users in the filter
    users_to_email = User.all.select {|user|
      @settings[:email_filter].empty? || @settings[:email_filter].include?(user.email.downcase)
    }

    users_to_email.each do |user|
      # TODO: Move this query into a single spec to improve readability
      # TODO: Consider including conflicting files in the email
      new_conflicts = Conflict.unresolved.by_user(user).status_changed_after(conflicts_newer_than).all
      resolved_conflicts = Conflict.resolved.by_user(user).status_changed_after(conflicts_newer_than).all
      unless new_conflicts.blank? && resolved_conflicts.blank?
        ConflictsMailer.conflicts_email(
            user,
            @settings[:email_override].present? ? @settings[:email_override] : user.email,
            repo_name,
            new_conflicts,
            resolved_conflicts,
            Conflict.unresolved.by_user(user).status_changed_before(conflicts_newer_than).all).deliver_now
      end
    end
  end

  def process_repo(repo_name)
    git = Git::Git.new("git@github.com:#{repo_name}.git", "#{File.join(@settings[:cache_directory], repo_name)}")

    start_time = DateTime.now

    setup_repo(git)

    # get a list of branches and add them to the DB
    get_branch_list(git).each do |branch|
      Branch.create_from_git_data(branch)
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.branches_not_updated_since(start_time).destroy_all

    # get the list of branches that are new or have been updated since they were last tested
    untested_branches = Branch.untested_branches
    if untested_branches.empty?
      Rails.logger.info("\nNo branches to process, exiting")
      return
    end
    Rails.logger.info("\nBranches to process: #{untested_branches.join(', ')}")

    tested_pairs = []
    all_branches = Branch.all
    untested_branches.each do |branch|
      Rails.logger.info("\nProcessing target branch: #{branch.name}")

      # exclude combinations we have already tested from the list
      # TODO: Extract into function
      branches_to_test = all_branches.select do |tested_branch|
        if tested_pairs.include?("#{branch.name}:#{tested_branch.name}")
          Rails.logger.debug("Skipping #{tested_branch.name}, already tested this combination")
          false
        elsif branch.name == tested_branch.name
          false
        else
          true
        end
      end

      # check this branch with the others to see if they conflict
      conflicts = get_conflicts(git, branch, branches_to_test)

      branches_to_test.each do |tested_branch|
        # see if we got a conflict for this branch
        matching_conflicts = conflicts.select do |conflict|
          conflict.contains_branch(tested_branch.name)
        end
        matching_conflicts.size <= 1 or raise "Found more than one conflict for the branch #{tested_branch}!"
        conflict = matching_conflicts[0]

        # record or clear the conflict based on the test result
        unless matching_conflicts.empty?
          Conflict.create!(branch, tested_branch, conflict.conflicting_files, start_time)
        else
          Conflict.clear!(branch, tested_branch, start_time)
        end

        # record the fact that we tested these branches
        tested_pairs << "#{branch.name}:#{tested_branch.name}"
        tested_pairs << "#{tested_branch.name}:#{branch.name}"
      end

      branch.mark_as_tested
    end

    # send notifications out
    send_conflict_emails(repo_name, start_time)
  end
end

