class UsersController < ApplicationController

  def new_unsubscribe
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:alert] = 'The user could not be found'
    redirect_to controller: 'errors', action: 'bad_request'
  end

  def create_unsubscribe
    @user = User.find(params[:id])
    @user.unsubscribe!
  end
end
