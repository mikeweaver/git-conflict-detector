class ConflictsMailer < ActionMailer::Base
  default from: "gitconflictdetector@noreply.com"
  default content_type: 'text/plain'

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
