class GithubPushHookHandler
  def initialize(push_hook_payload)
    @payload = push_hook_payload
  end

  def handle!
    Rails.logger.info(@payload)
  end
  handle_asynchronously :handle!
end
