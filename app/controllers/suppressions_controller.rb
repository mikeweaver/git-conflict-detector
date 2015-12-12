class SuppressionsController < ApplicationController

  SUPPRESSION_RANGES = ['1 day', '1 week', 'Forever']



  def new
    @suppression_range_conflict = '1 week'
    @suppression_range_branch_a = '1 week'
    @suppression_range_branch_b = '1 week'
    @suppress_conflict_until_files_change = true
    @suppress_conflict = true
    @suppress_branch_a = false
    @suppress_branch_b = false
  end

  def create
    puts '********************'
    puts @suppression
  end

  def list
  end

  def destroy
  end
end
