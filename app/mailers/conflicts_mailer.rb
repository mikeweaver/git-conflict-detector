class ConflictsMailer < ActionMailer::Base
  default from: "from@example.com"
  default content_type: 'text/plain'

  def conflicts_email(user, new_conflicts, existing_conflicts)
    @user = user
    @new_conflicts = new_conflicts.sort
    @existing_conflicts = existing_conflicts.sort
    mail(to: @user.email, subject: 'Conflicts Detected')
  end
end
