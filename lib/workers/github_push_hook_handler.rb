class GithubPushHookHandler
  PENDING_QUEUE = 'pending'
  PROCESSING_QUEUE = 'processing'
  CONTEXT_NAME = 'JIRA Checker'
  STATE_DESCRIPTIONS = {
      Github::Api::Status::STATE_PENDING => 'Branch is being examined',
      Github::Api::Status::STATE_SUCCESS => 'Branch is OK',
      Github::Api::Status::STATE_FAILED => 'Branch was rejected'
  }

  def initialize(push_hook_payload)
    @payload = Github::Api::PushHookPayload.new(push_hook_payload)
  end

  def queue!
    Rails.logger.info('Queueing request')
    Rails.logger.info(@payload)
    set_status_for_repo!(Github::Api::Status::STATE_PENDING, STATE_DESCRIPTIONS[Github::Api::Status::STATE_PENDING])
    process!
  end
  handle_asynchronously(:queue!, queue: PENDING_QUEUE)

  def process!
    Rails.logger.info('Processing request')
    status = handle_process_request!
    set_status_for_repo!(status, STATE_DESCRIPTIONS[status])
  end
  handle_asynchronously(:process!, queue: PROCESSING_QUEUE)

  private

  def handle_process_request!
    push = Push.create_from_github_data!(@payload)
    PushManager.process_push(push)
  end

  def set_status_for_repo!(state, description)
    api = Github::Api::Status.new(Rails.application.secrets.github_user_name,
                                  Rails.application.secrets.github_password)
    api.set_status(@payload.repository_owner_name,
                   @payload.repository_name,
                   @payload.sha,
                   CONTEXT_NAME,
                   state,
                   description,
                   'http://moreinfohere.com')
  end
end
