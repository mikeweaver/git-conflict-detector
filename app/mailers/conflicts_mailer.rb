class ConflictsMailer < ActionMailer::Base
  default from: "from@example.com"
  default content_type: 'text/plain'

  def conflicts_email(user, conflicts)

    @user = user
    @conflicts = conflicts
    mail(to: @user.email, subject: 'Conflicts Detected')
  end
end
