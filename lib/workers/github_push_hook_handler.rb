class GithubPushHookHandler
  PENDING_QUEUE = 'push_pending'
  PROCESSING_QUEUE = 'push_processing'
  CONTEXT_NAME = 'Pre-Deploy Checker'
  STATE_DESCRIPTIONS = {
      Github::Api::Status::STATE_PENDING => 'Processing...',
      Github::Api::Status::STATE_SUCCESS => 'OK to deploy',
      Github::Api::Status::STATE_FAILED => 'Has unapproved errors'
  }

  def queue!(push_hook_payload)
    Rails.logger.info('Queueing request')
    payload = Github::Api::PushHookPayload.new(push_hook_payload)
    Rails.logger.info(payload)

    if should_ignore_push?(payload)
      Rails.logger.info("Ignoring branch #{payload.branch_name} because it is in the ignore list")
    elsif should_include_push?(payload)
      Rails.logger.info("Queueing branch #{payload.branch_name}")
      push = Push.create_from_github_data!(payload)
      set_status_for_push!(push)
      submit_push_for_processing!(push)
    else
      Rails.logger.info("Ignoring branch #{payload.branch_name} because it is not in the include list")
    end
  end
  handle_asynchronously(:queue!, queue: PENDING_QUEUE)

  def process_push!(push_id)
    Rails.logger.info("Processing push id #{push_id}")
    push = PushManager.process_push!(Push.find(push_id))
    set_status_for_push!(push)
  end
  handle_asynchronously(:process_push!, queue: PROCESSING_QUEUE)

  def submit_push_for_processing!(push)
    push.status = Github::Api::Status::STATE_PENDING
    push.save!
    process_push!(push.id)
  end

  private

  def set_status_for_push!(push)
    api = Github::Api::Status.new(Rails.application.secrets.github_user_name,
                                  Rails.application.secrets.github_password)
    api.set_status(push.branch.repository.name,
                   push.head_commit.sha,
                   CONTEXT_NAME,
                   push.status,
                   STATE_DESCRIPTIONS[push.status.to_sym],
                   'http://moreinfohere.com')
  end

  def should_ignore_push?(payload)
    GlobalSettings.jira.ignore_branches.include_regexp?(payload.branch_name, regexp_options=Regexp::IGNORECASE)
  end

  def should_include_push?(payload)
    if GlobalSettings.jira.only_branches.any?
      GlobalSettings.jira.only_branches.include_regexp?(payload.branch_name, regexp_options=Regexp::IGNORECASE)
    else
      true
    end
  end
end
