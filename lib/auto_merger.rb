class AutoMerger < BranchManager

  def run
    # destroy record of previous merges
    Merge.destroy_all

    # make sure we have the latest list of branches from the origin in our database
    update_branch_list!

    # get the list of branches to merge into
    target_branches = get_target_branches
    if target_branches.empty?
      Rails.logger.info("\nNo branches to process, exiting")
      return
    end
    Rails.logger.info("\nBranches to process: #{target_branches.join(', ')}")

    source_branch = get_source_branch
    unless source_branch.present?
      Rails.logger.info("\nSource branch #{@settings.source_branch_name} not found, exiting")
      return
    end

    # note the time at which we started creating merge records, so we only send out emails for the new ones
    start_time = DateTime.now

    merge_and_push_branches(source_branch, target_branches)

    # send notifications out
    MergeMailer.send_merge_emails(
        @settings.repository_name,
        start_time)
  end

  private

  def get_target_branches
    # get the list of branches that passed the filter
    filter_branch_list(Branch.from_repository(@settings.repository_name))
  end

  def get_source_branch
    source_branch = Branch.from_repository(@settings.repository_name).with_name(@settings.source_branch_name)
    if source_branch.empty?
      nil
    elsif source_branch.size > 1
      raise "More than one branch found with name #{@settings.source_branch_name}!"
    else
      source_branch[0]
    end
  end

  def merge_and_push_branch(target_branch, source_branch)
    # don't try to merge the branch with itself
    target_branch.name != source_branch.name or return

    # get onto the target branch
    @git.checkout_branch(target_branch.name)

    Rails.logger.debug("Attempt to merge #{source_branch.name} into #{target_branch.name}")
    conflict = @git.detect_conflicts(target_branch.name, source_branch.name, keep_changes: true)
    unless conflict.present?
      Rails.logger.info("MERGED: #{source_branch.name} has been merged into #{target_branch.name} without conflicts")
      if @git.push
        Rails.logger.info("PUSHED: #{target_branch.name} to origin")
        Merge.create!(source_branch: source_branch, target_branch: target_branch, successful: true)
      else
        Rails.logger.info("NO-OP: #{target_branch.name} is already up to date with origin")
      end
    else
      Rails.logger.info("CONFLICT: #{target_branch.name} conflicts with #{source_branch.name}\nConflicting files:\n#{conflict.conflicting_files}")
      Merge.create!(source_branch: source_branch, target_branch: target_branch, successful: false)
    end
  end

  def merge_and_push_branches(source_branch, target_branches)
    target_branches.each do |target_branch|
      Rails.logger.info("\nProcessing target branch: #{target_branch.name}")
      merge_and_push_branch(target_branch, source_branch)
    end
  end
end

