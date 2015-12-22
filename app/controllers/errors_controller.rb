class ErrorsController < ApplicationController
  def bad_request
    @message = params['message']
    render(:status => 400)
  end

  def not_found
    render(:status => 404)
  end

  def internal_server_error
    render(:status => 500)
  end
end
