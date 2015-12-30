class MergeMailer < ActionMailer::Base
  default from: "Auto Merger <#{GlobalSettings.email_from_address}>"
  default content_type: 'text/html'

  def self.send_merge_emails(repository_name, merges_newer_than)
    User.subscribed_users.users_with_emails(GlobalSettings.email_filter).each do |user|
      if GlobalSettings.email_override.present?
        user.email = GlobalSettings.email_override
      end
      maybe_send_merge_email_to_user(user, repository_name,  merges_newer_than).deliver_now
    end
  end

  def maybe_send_merge_email_to_user(user, repository_name, merges_newer_than)
    Rails.logger.info("Determining if merge email should be sent to #{user.email}")
    @repository_name = repository_name

    scope = Merge.from_repository(repository_name).by_target_user(user).created_after(merges_newer_than)
    successful_merges = scope.successful
    unsuccessful_merges = scope.unsuccessful
    unless successful_merges.blank? && unsuccessful_merges.blank?
      send_merge_email_to_user(
          user,
          repository_name,
          successful_merges,
          unsuccessful_merges)
    end
  end

  def map_merge_list_to_hash(merge_list)
    hash = Hash.new([].freeze)
    merge_list.each do |merge|
      hash[merge.source_branch] += [merge.target_branch]
    end
    hash
  end

  def send_merge_email_to_user(user, repository_name, successful_merges, unsuccessful_merges)
    Rails.logger.info("Sending merge email to #{user.email}")
    @user = user
    @successful_merges = map_merge_list_to_hash(successful_merges)
    @unsuccessful_merges = map_merge_list_to_hash(unsuccessful_merges)
    mail(to: user.email, bcc: GlobalSettings.bcc_emails, subject: "Automatic Merges in #{repository_name}", template_name: 'merge_email')
  end
end
