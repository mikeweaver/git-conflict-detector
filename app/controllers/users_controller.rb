class UsersController < ApplicationController
  def unsubscribe
    @user = User.find(params[:id])
    @user.unsubscribe!
  end
end
