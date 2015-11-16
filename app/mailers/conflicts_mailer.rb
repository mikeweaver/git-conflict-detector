class ConflictsMailer < ActionMailer::Base
  default from: "gitconflictdetector@noreply.com"
  default content_type: 'text/plain'

  def self.send_conflict_emails(repo_name, conflicts_newer_than, email_filter_list, email_override)
    # only email users in the filter, or if filter is empty, email all users
    users_to_email = User.all.select {|user|
      email_filter_list.empty? || email_filter_list.include?(user.email.downcase)
    }

    users_to_email.each do |user|
      suppressed_branch_ids = ConflictNotificationSuppression.not_expired.by_user(user).collect do |supression|
        supression.branch.id
      end

      new_conflicts = Conflict.unresolved.by_user(user).status_changed_after(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).all
      resolved_conflicts = Conflict.resolved.by_user(user).status_changed_after(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).all
      unless new_conflicts.blank? && resolved_conflicts.blank?
        ConflictsMailer.conflicts_email(
            user,
            email_override.present? ? email_override : user.email,
            repo_name,
            new_conflicts,
            resolved_conflicts,
            Conflict.unresolved.by_user(user).status_changed_before(conflicts_newer_than).exclude_branches_with_ids(suppressed_branch_ids).all).deliver_now
      end
    end
  end

  def conflicts_email(user, send_to_email, repo_name, new_conflicts, resolved_conflicts, existing_conflicts)
    Rails.logger.info("Sending email to #{send_to_email}")
    @user = user
    @repo_name = repo_name
    @new_conflicts = new_conflicts.sort.sort
    @resolved_conflicts = resolved_conflicts.sort
    @existing_conflicts = existing_conflicts.sort
    mail(to: send_to_email, subject: 'Conflicts Detected')
  end
end
