class JiraStatusController < ApplicationController
  def show_status_for_commit
    @push = Push.joins(:head_commit).where('commits.sha = ?', params[:sha]).first
  rescue ActiveRecord::RecordNotFound => e
    flash[:alert] = 'The commit could not be found'
    redirect_to controller: 'errors', action: 'bad_request'
  end
end
