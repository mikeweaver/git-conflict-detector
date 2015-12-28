class ConflictsMailer < ActionMailer::Base
  default from: "gitconflictdetector@noreply.com"
  default content_type: 'text/plain'

  def self.send_conflict_emails(repository_name, conflicts_newer_than, exclude_branches_if_owned_by_user, hidden_file_list)
    User.subscribed_users.users_with_emails(GlobalSettings.email_filter).each do |user|
      if GlobalSettings.email_override.present?
        user.email = GlobalSettings.email_override
      end
      maybe_send_conflict_email_to_user(user, repository_name, conflicts_newer_than, exclude_branches_if_owned_by_user, hidden_file_list).deliver_now
    end
  end

  def maybe_send_conflict_email_to_user(user, repository_name, conflicts_newer_than, exclude_branches_if_owned_by_user, hidden_file_list)
    Rails.logger.info("Determining if conflict email should be sent to #{user.email}")
    @repository_name = repository_name
    @hidden_file_list = hidden_file_list

    suppressed_branch_ids = BranchNotificationSuppression.suppressed_branch_ids(user)

    suppressed_conflict_ids = ConflictNotificationSuppression.suppressed_conflict_ids(user)

    suppressed_owned_branch_ids = exclude_branches_if_owned_by_user.collect do |branch|
      branch.id
    end

    scope = Conflict.from_repository(repository_name).by_user(user).exclude_branches_with_ids(suppressed_branch_ids).exclude_non_self_conflicting_authored_branches_with_ids(user, suppressed_owned_branch_ids).exclude_conflicts_with_ids(suppressed_conflict_ids)

    new_conflicts = scope.unresolved.status_changed_after(conflicts_newer_than).all
    resolved_conflicts = scope.resolved.status_changed_after(conflicts_newer_than).all
    unless new_conflicts.blank? && resolved_conflicts.blank?
      send_conflict_email_to_user(
          user,
          repository_name,
          new_conflicts,
          resolved_conflicts,
          scope.unresolved.status_changed_before(conflicts_newer_than).all)
    end
  end

  def send_conflict_email_to_user(user, repository_name, new_conflicts, resolved_conflicts, existing_conflicts)
    Rails.logger.info("Sending conflict email to #{user.email}")
    @user = user
    @new_conflicts = new_conflicts.sort.sort
    @resolved_conflicts = resolved_conflicts.sort
    @existing_conflicts = existing_conflicts.sort
    mail(to: user.email, bcc: GlobalSettings.bcc_emails, subject: 'Conflicts Detected in #{repository_name}', template_name: 'conflicts_email')
  end
end
