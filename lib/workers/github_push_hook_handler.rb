class GithubPushHookHandler
  PENDING_QUEUE = 'pending'
  PROCESSING_QUEUE = 'processing'
  CONTEXT_NAME = 'JIRA Checker'
  PENDING_DESCRIPTION = 'Branch is being examined'
  SUCCESS_DESCRIPTION = 'Branch is OK'

  def initialize(push_hook_payload)
    @payload = Github::Api::PushHookPayload.new(push_hook_payload)

  end

  def queue!
    Rails.logger.info('Queueing request')
    Rails.logger.info(@payload)
    set_status_for_repo(Github::Api::Status::STATE_PENDING, PENDING_DESCRIPTION)
    process!
  end
  handle_asynchronously(:queue!, queue: PENDING_QUEUE)

  def process!
    Rails.logger.info('Processing request')
    push = Push.create_from_github_data!(@payload)
    # clone repo
    # diff with master to get list of commits
    # save list of orphaned commits
    # lookup tickets in JIRA
    # save tickets
    # compute status
    push.status = Github::Api::Status::STATE_SUCCESS
    push.save!
    set_status_for_repo(Github::Api::Status::STATE_SUCCESS, SUCCESS_DESCRIPTION)
  end
  handle_asynchronously(:process!, queue: PROCESSING_QUEUE)

  private

  def set_status_for_repo(state, description)
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
