class ConflictDetector < BranchManager

  def run
    # note the time at which we queried the git origin for the branch list
    # the branches may be updated while we are running, so we use this time
    # to indicate when we tested them. Otherwise, we would "lose" the changes
    # that were committed while we were running
    start_time = DateTime.now

    # make sure we have the latest list of branches from the origin in our database
    update_branch_list!

    # get the list of branches that are new or have been updated since they were last tested
    untested_branches = get_branches_not_tested_since
    if untested_branches.empty?
      Rails.logger.info("\nNo new/updated branches to process, exiting")
      return
    end
    Rails.logger.info("\nNew/updated branches to process: #{untested_branches.join(', ')}")

    # test the untested branches for conflicts with all the branches
    test_branches(untested_branches, get_all_branches, start_time)

    # send notifications out
    ConflictsMailer.send_conflict_emails(
        @settings.repository_name,
        start_time,
        Branch.where(name: @settings.suppress_conflicts_for_owners_of_branches),
        @settings.ignore_conflicts_in_file_paths)
  end

  private

  def exceeded_maximum_branches_to_check(branches_checked)
    GlobalSettings.maximum_branches_to_check.present? &&
        GlobalSettings.maximum_branches_to_check > 0 &&
        branches_checked > GlobalSettings.maximum_branches_to_check
  end

  def get_conflicts(target_branch, source_branches)
    conflicts = []
    branches_checked = 0
    source_branches.each do |source_branch|
      # break if we have tested enough branches already
      branches_checked += 1
      if exceeded_maximum_branches_to_check(branches_checked)
        Rails.logger.warn("WARNING: Checked the maximum number of branches allowed, #{GlobalSettings.maximum_branches_to_check}, exiting early")
        break
      end

      conflict = get_conflict(target_branch.name, source_branch.name)
      if conflict
        conflicts << conflict
      end
    end

    conflicts
  end
  
  def get_conflict(target_branch_name, source_branch_name)
    # don't try to merge the branch with itself
    unless target_branch_name == source_branch_name
      Rails.logger.debug("Attempting to merge #{source_branch_name}")
      success, conflict = @git.merge_branches(target_branch_name, source_branch_name, keep_changes: false)
      if success
        Rails.logger.info("MERGED: #{source_branch_name} can be merged into #{target_branch_name} without conflicts")
      elsif conflict.present?
        Rails.logger.info("CONFLICT: #{target_branch_name} conflicts with #{source_branch_name}\nConflicting files:\n#{conflict.conflicting_files}")
      else
        Rails.logger.info("MERGED: #{source_branch_name} was already up to date with #{target_branch_name}")
      end
      conflict
    end
  end

  def get_conflicting_files_to_ignore(conflict)
    inherited_files = get_inherited_conflicting_files(conflict)
    unless inherited_files.empty?
      Rails.logger.info("Ignoring files conflicting between #{conflict.branch_a} and #{conflict.branch_b} because they were inherited from the parent branch.\n#{inherited_files}")
    end

    files_to_ignore = get_files_to_ignore(conflict)
    unless files_to_ignore.empty?
      Rails.logger.info("Ignoring files conflicting between #{conflict.branch_a} and #{conflict.branch_b} because they are on the ignore list.\n#{files_to_ignore}")
    end

    (inherited_files + files_to_ignore).uniq
  end

  def get_inherited_conflicting_files(conflict)
    files_changed_on_branch_a = @git.diff_branch_with_ancestor(conflict.branch_a, @settings.default_branch_name)
    files_changed_on_branch_b = @git.diff_branch_with_ancestor(conflict.branch_b, @settings.default_branch_name)
    # Only files that were modified in both branches are conflicts, we should ignore all the others.
    # This is because files that were only modified in one branch, are either not conflicting,
    # or were inherited (and are showing up in the branch diff for some unknown reason)
    # Logic below explained: Get list of files that were modified in both branches. Remove this list from the list
    # of conflicting files and what you are left with the list of conflicting files that should be ignored.
    conflict.conflicting_files - (files_changed_on_branch_a & files_changed_on_branch_b).uniq
  end

  def get_files_to_ignore(conflict)
    conflict.conflicting_files.select_regex(@settings.ignore_conflicts_in_file_paths)
  end

  def get_branches_not_tested_since
    # get the list of branches that passed the filter AND are new or have been updated since they were last tested
    filter_branch_list(Branch.from_repository(@settings.repository_name).untested_branches)
  end

  def get_all_branches
    # get the list of branches that passed the filter
    filter_branch_list(Branch.from_repository(@settings.repository_name))
  end

  def exclude_tested_branches(branch_to_test, branches_to_test, tested_pairs)
    branches_to_test.select do |tested_branch|
      if tested_pairs.include?("#{branch_to_test.name}:#{tested_branch.name}")
        Rails.logger.debug("Skipping #{tested_branch.name}, already tested this combination")
        false
      elsif branch_to_test.name == tested_branch.name
        false
      else
        true
      end
    end
  end

  def create_branch_name_pairs(branch_a, branch_b)
    ["#{branch_a.name}:#{branch_b.name}", "#{branch_b.name}:#{branch_a.name}"]
  end

  def get_conflict_that_contains_branch(conflicts, branch)
    # see if we got a conflict for this branch
    matching_conflicts = conflicts.select do |conflict|
      conflict.contains_branch(branch.name)
    end
    matching_conflicts.size <= 1 or raise "Found more than one conflict for the branch #{tested_branch}!"
    matching_conflicts[0]
  end

  def create_or_resolve_conflict(target_branch, source_branch, start_time, conflict)
    if conflict.nil?
      Rails.logger.info("RESOLVED: Conflict between #{source_branch.name} and #{target_branch.name} no longer exists")
      Conflict.resolve!(target_branch, source_branch, start_time)
    else
      if (conflict.conflicting_files - get_conflicting_files_to_ignore(conflict)).empty?
        Rails.logger.info("RESOLVED: Ignoring conflict between #{source_branch.name} and #{target_branch.name} because all the conflicting files were ignored")
        Conflict.resolve!(target_branch, source_branch, start_time)
      else
        Rails.logger.info("CONFLICT: Creating conflict between #{source_branch.name} and #{target_branch.name}")
        # TODO store ignored files in the conflict record so they can be sent in email
        Conflict.create!(target_branch, source_branch, conflict.conflicting_files, start_time)
      end
    end
  end

  def test_branches(untested_branches, all_branches, start_time)
    tested_pairs = []
    untested_branches.each do |branch|
      Rails.logger.info("\nProcessing target branch: #{branch.name}")

      # exclude combinations we have already tested from the list
      branches_to_test = exclude_tested_branches(branch, all_branches, tested_pairs)

      # check this branch with the others to see if they conflict
      conflicts = get_conflicts(branch, branches_to_test)

      branches_to_test.each do |tested_branch|
        Rails.logger.info("Looking at #{tested_branch}")
        conflict = get_conflict_that_contains_branch(conflicts, tested_branch)
        create_or_resolve_conflict(branch, tested_branch, start_time, conflict)
        tested_pairs += create_branch_name_pairs(branch, tested_branch)
      end

      branch.mark_as_tested!
    end
  end
end

