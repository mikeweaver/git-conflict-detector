class SuppressionsController < ApplicationController
  before_action :load_user_and_conflict, only: [:new, :create]

  SUPPRESSION_DURATION_ONE_DAY = '1 day'
  SUPPRESSION_DURATION_ONE_WEEK = '1 week'
  SUPPRESSION_DURATION_FOREVER = 'Forever'
  SUPPRESSION_DURATIONS = [
      SUPPRESSION_DURATION_ONE_DAY,
      SUPPRESSION_DURATION_ONE_WEEK,
      SUPPRESSION_DURATION_FOREVER]

  def new
  end

  def create
    suppression_params = params['suppression']

    if suppression_params['suppress_conflict'] == '1'
      #"suppress_conflict_until_files_change"=>"0" TODO: Add support for this

      @conflict_notification_suppression = ConflictNotificationSuppression.create!(
          @user,
          @conflict,
          suppression_duration_string_to_suppression_date(suppression_params['suppression_duration_conflict']))
    end

    if suppression_params['suppress_branch_a'] == '1'
      @branch_a_notification_suppression = BranchNotificationSuppression.create!(
          @user,
          @conflict.branch_a,
          suppression_duration_string_to_suppression_date(suppression_params['suppression_duration_branch_a']))
    end

    if suppression_params['suppress_branch_b'] == '1'
      @branch_b_notification_suppression = BranchNotificationSuppression.create!(
          @user,
          @conflict.branch_b,
          suppression_duration_string_to_suppression_date(suppression_params['suppression_duration_branch_b']))
    end

    unless @conflict_notification_suppression || @branch_a_notification_suppression || @branch_b_notification_suppression
        redirect_to action: 'new', conflict_id: @conflict.id, user_id: @user.id
    end
  end

  def list
  end

  def destroy
  end

  private

  def suppression_duration_string_to_suppression_date(duration_string)
    case duration_string
      when SUPPRESSION_DURATION_ONE_DAY
        1.day.from_now
      when SUPPRESSION_DURATION_ONE_WEEK
        1.week.from_now
      when SUPPRESSION_DURATION_FOREVER
        nil
      else
        raise "Unknown suppression duration: #{duration_string}"
    end
  end

  def load_user_and_conflict
    @conflict = Conflict.find(params['conflict_id'])
    @user = User.find(params['user_id'])
    unless @conflict.branch_a.author.id == @user.id || @conflict.branch_b.author.id == @user.id
      raise "User id #{@user.id} doesn't own conflict id #{@conflict.id}"
    end
    @repository_name = @conflict.branch_a.repository.name
    nil
  end
end
