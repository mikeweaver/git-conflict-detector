class GithubPushHookHandler
  PENDING_QUEUE = 'push_pending'
  PROCESSING_QUEUE = 'push_processing'
  CONTEXT_NAME = 'JIRA Checker'
  STATE_DESCRIPTIONS = {
      Github::Api::Status::STATE_PENDING => 'Branch is being examined',
      Github::Api::Status::STATE_SUCCESS => 'Branch is OK',
      Github::Api::Status::STATE_FAILED => 'Branch was rejected'
  }

  def queue!(push_hook_payload)
    Rails.logger.info('Queueing request')
    payload = Github::Api::PushHookPayload.new(push_hook_payload)
    Rails.logger.info(payload)
    push = Push.create_from_github_data!(payload)
    set_status_for_push!(push)
    submit_push_for_processing!(push)
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
end
