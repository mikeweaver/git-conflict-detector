class ConflictsMailer < ActionMailer::Base
  default from: "gitconflictdetector@noreply.com"
  default content_type: 'text/plain'

  def self.send_conflict_emails(repo_name, conflicts_newer_than, email_filter_list, email_override, exclude_branches_if_owned_by_user, hidden_file_list)
    User.subscribed_users.users_with_emails(email_filter_list).each do |user|
      if email_override.present?
        user.email = email_override
      end
      maybe_send_conflict_email_to_user(user, repo_name, conflicts_newer_than, exclude_branches_if_owned_by_user, hidden_file_list).deliver_now
    end
  end

  def maybe_send_conflict_email_to_user(user, repo_name, conflicts_newer_than, exclude_branches_if_owned_by_user, hidden_file_list)
    @repo_name = repo_name
    @hidden_file_list = hidden_file_list

    suppressed_branch_ids = BranchNotificationSuppression.suppressed_branch_ids(user)

    suppressed_conflict_ids = ConflictNotificationSuppression.suppressed_conflict_ids(user)

    suppressed_owned_branch_ids = exclude_branches_if_owned_by_user.collect do |branch|
      branch.id
    end

    new_conflicts = Conflict.unresolved.by_user(user).status_changed_after(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).exclude_non_self_conflicting_authored_branches_with_ids(user, suppressed_owned_branch_ids).exclude_conflicts_with_ids(suppressed_conflict_ids).all
    resolved_conflicts = Conflict.resolved.by_user(user).status_changed_after(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).exclude_non_self_conflicting_authored_branches_with_ids(user, suppressed_owned_branch_ids).exclude_conflicts_with_ids(suppressed_conflict_ids).all
    unless new_conflicts.blank? && resolved_conflicts.blank?
      send_conflict_email_to_user(
          user,
          new_conflicts,
          resolved_conflicts,
          Conflict.unresolved.by_user(user).status_changed_before(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).exclude_non_self_conflicting_authored_branches_with_ids(user, suppressed_owned_branch_ids).exclude_conflicts_with_ids(suppressed_conflict_ids).all)
    end
  end

  def send_conflict_email_to_user(user, new_conflicts, resolved_conflicts, existing_conflicts)
    Rails.logger.info("Sending email to #{user.email}")
    @user = user
    @new_conflicts = new_conflicts.sort.sort
    @resolved_conflicts = resolved_conflicts.sort
    @existing_conflicts = existing_conflicts.sort
    mail(to: user.email, subject: 'Conflicts Detected', template_name: 'conflicts_email')
  end
end
