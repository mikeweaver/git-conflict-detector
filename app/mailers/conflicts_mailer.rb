class ConflictsMailer < ActionMailer::Base
  default from: "from@example.com"
  default content_type: 'text/plain'

  def conflicts_email(user, new_conflicts, resolved_conflicts, existing_conflicts)
    puts "Sending email to #{user.email}"
    @user = user
    @new_conflicts = new_conflicts.sort
    @resolved_conflicts = resolved_conflicts.sort
    @existing_conflicts = existing_conflicts.sort
    #mail(to: @user.email, subject: 'Conflicts Detected')
    mail(to: 'mike@weaverfamily.net', subject: 'Conflicts Detected')
  end
end
