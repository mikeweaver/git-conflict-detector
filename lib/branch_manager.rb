require_relative '../environment'
require_relative '../models/branch'
require_relative '../models/conflict'
require_relative '../models/user'

class BranchManager

  def add_branch(branch)
    # if branch exists, then update the last_modfied_date, set last_checked_date to nil
    # otherwise, insert branch
  end

  def add_conflict(branch_a, branch_b, checked_at_date)
    # if conflict exists, then update the last_tested_date, set last_checked_date to nil
    # otherwise, insert branch
  end

  def get_list_of_modified_branches(checked_at_date)
    give me all the branches that
    have been modified since checked_at_date
  end

  def




end
