class ConflictDetector < BranchManager

  def run
    # note the time at which we queried the git origin for the branch list
    # the branches may be updated while we are running, so we use this time
    # to indicate when we tested them. Otherwise, we would "lose" the changes
    # that were committed while we were running
    start_time = DateTime.now

    # get the list of branches that are new or have been updated since they were last tested
    untested_branches = get_branches_not_tested_since
    if untested_branches.empty?
      Rails.logger.info("\nNo new/updated branches to process, exiting")
      return
    end
    Rails.logger.info("\nNew/updated branches to process: #{untested_branches.join(', ')}")

    # test the branches for conflicts
    test_branches(untested_branches, start_time)

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
    # get onto the target branch
    @git.checkout_branch(target_branch.name)

    conflicts = []
    branches_checked = 0
    source_branches.each do |source_branch|
      # break if we have tested enough branches already
      branches_checked += 1
      if exceeded_maximum_branches_to_check(branches_checked)
        Rails.logger.warn("WARNING: Checked the maximum number of branches allowed, #{GlobalSettings.maximum_branches_to_check}, exiting early")
        break
      end

      # don't try to merge the branch with itself
      next if target_branch.name == source_branch.name

      Rails.logger.debug("Attempt to merge #{source_branch.name}")
      conflict = @git.detect_conflicts(target_branch.name, source_branch.name)
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

  def get_branches_not_tested_since
    # make sure we have the latest list of branches from the origin
    update_branch_list!

    # get the list of branches that are new or have been updated since they were last tested
    Branch.untested_branches
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

  def test_branches(untested_branches, start_time)

    tested_pairs = []
    all_branches = Branch.all
    untested_branches.each do |branch|
      Rails.logger.info("\nProcessing target branch: #{branch.name}")

      # exclude combinations we have already tested from the list
      branches_to_test = exclude_tested_branches(branch, all_branches, tested_pairs)

      # check this branch with the others to see if they conflict
      conflicts = get_conflicts(branch, branches_to_test)

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
          Conflict.resolve!(branch, tested_branch, start_time)
        end

        # record the fact that we tested these branches
        tested_pairs << "#{branch.name}:#{tested_branch.name}"
        tested_pairs << "#{tested_branch.name}:#{branch.name}"
      end

      branch.mark_as_tested!
    end
  end
end

