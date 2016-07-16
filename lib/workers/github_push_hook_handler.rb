class GithubPushHookHandler
  PENDING_QUEUE = 'pending'
  PROCESSING_QUEUE = 'processing'
  CONTEXT_NAME = 'JIRA Checker'
  PENDING_DESCRIPTION = 'Branch is being examined'
  SUCCESS_DESCRIPTION = 'Branch is OK'

  def initialize(push_hook_payload)
    @payload = push_hook_payload.with_indifferent_access
  end

  def queue!
    Rails.logger.info('Queueing request')
    Rails.logger.info(@payload)
    set_status_for_repo(Github::Api::Status::STATE_PENDING, PENDING_DESCRIPTION)
    process!
    # TODO: Rescue exceptions
  end
  handle_asynchronously(:queue!, queue: PENDING_QUEUE)

  def process!
    Rails.logger.info('Processing request')
    set_status_for_repo(Github::Api::Status::STATE_SUCCESS, SUCCESS_DESCRIPTION)
    # TODO: Rescue exceptions
  end
  handle_asynchronously(:process!, queue: PROCESSING_QUEUE)

  private

  def set_status_for_repo(state, description)
    api = Github::Api::Status.new(Rails.application.secrets.github_user_name,
                                  Rails.application.secrets.github_password)
    api.set_status(repository_owner_name,
                   repository_name,
                   sha,
                   CONTEXT_NAME,
                   state,
                   description,
                   'http://moreinfohere.com')
  end

  def sha
    # TODO raise if SHA is all zeros
    @payload[:after]
  end

  def repository
    @payload[:repository] or raise 'Payload does not include repository'
  end

  def repository_name
    repository[:name]
  end

  def repository_owner
    repository[:owner] or raise 'Payload does not include repository owner'
  end

  def repository_owner_name
    repository_owner[:name]
  end
end
