require 'yaml'
require 'fileutils'
require_relative 'git'
require_relative '../app/models/branch'

# TODO: Cache results and suppress duplicate warnings
# TODO: Cache results and skip merges that are already known failures
# TODO: OO this thing, its a mess

class ConflictDetector

  def initialize(settings_file_path='config/settings.yml')
    @settings = YAML.load(File.read(settings_file_path)).symbolize_keys
    FileUtils.mkdir_p(@settings[:log_directory])
    FileUtils.mkdir_p(@settings[:cache_directory])
  end

  def log_message(message)
    puts(message)
    File.open(@settings[:log_file], 'a') {|f| f.write("#{message}\n") }
  end

  def call_git(git, command, run_in_repo_path=true)
    log_message("Cmd: git #{command}")
    git.execute(command, run_in_repo_path)
  end

  def should_ignore_branch_by_list?(branch)
    @settings[:ignore_branches].any? do |regex|
      branch =~ Regexp.new(regex)
    end
  end

  def should_ignore_branch_by_date?(branch)
    branch.last_modified_date < (Date.today - @settings[:ignore_branches_modified_days_ago])
  end

  def should_include_branch?(branch)
    @settings[:only_branches] or return true

    @settings[:only_branches].any? do |regex|
      branch =~ Regexp.new(regex)
    end
  end

  def should_ignore_conflicts?(conflicts)
    conflicts.all? do |conflict|
      @settings[:ignore_conflicts_in_file_paths].any? do |regex|
        conflict =~ Regexp.new(regex)
      end
    end
  end

  def setup_repo(git)
    if Dir.exists?("#{git.repo_path}")
      # cleanup any changes that might have been left over if we crashed while running
      call_git(git, 'reset --hard origin')
      call_git(git, 'clean -f -d')

      # move to the master branch
      call_git(git, "checkout #{@settings[:master_branch_name]}")

      # remove branches that no longer exist on origin and update all branches that do
      call_git(git, 'fetch --prune --all')

      # pull all of the branches
      call_git(git, 'pull --all')
    else
      call_git(git, "clone #{git.repo_url} #{git.repo_path}", false)
    end
  end

  def get_branch_list(git)
    branches = git.get_branch_list

    branches.delete_if do |branch|
      if should_ignore_branch_by_list?(branch)
        log_message("Skipping branch #{branch.name}, it is on the ignore list")
        true
      elsif !should_include_branch?(branch)
        log_message("Skipping branch #{branch.name}, it is not on the include list")
        true
      elsif should_ignore_branch_by_date?(branch)
        log_message("Skipping branch #{branch.name}, it has not been modified in over #{@settings[:ignore_branches_modified_days_ago]} days")
        true
      else
        false
      end
    end
  end

  def get_conflicting_branch_names(git, target_branch, source_branches)
    # get onto the target branch
    git.execute("checkout #{target_branch.name}")
    git.execute("reset --hard origin/#{target_branch.name}")

    conflicting_branch_names = []
    branches_checked = 0
    source_branches.each do |source_branch|
      # break if we have tested enough branches already
      branches_checked += 1
      if @settings[:maximum_branches_to_check] && (branches_checked > @settings[:maximum_branches_to_check])
        log_message("WARNING: Checked the maximum number of branches allowed, #{@settings[:maximum_branches_to_check]}, exiting early")
        break
      end

      # don't try to merge the branch with itself
      next if target_branch.name == source_branch.name

      log_message("Attempt to merge #{source_branch.name}")
      conflicts = git.detect_conflicts(target_branch.name, source_branch.name)
      if conflicts.empty?
        log_message("SUCCESS: #{source_branch.name} can be merged into #{target_branch.name} without conflicts")
      else
        if should_ignore_conflicts?(conflicts)
          log_message("#{target_branch.name} conflicts with #{source_branch.name}, but all conflicting files are on the ignore list.")
        else
          log_message("WARNING: #{target_branch.name} conflicts with #{source_branch.name}\nConflicting files:\n#{conflicts}")
          conflicting_branch_names << source_branch.name
        end
      end
    end

    conflicting_branch_names
  end

  def send_conflict_emails(conflicts_newer_than)
    User.all.each do |user|
      conflicts = Conflict.unresolved.by_user(user).after_tested_date(conflicts_newer_than).all
      unless conflicts.blank?
        ConflictsMailer.conflicts_email(user, conflicts).deliver_now
      end
    end
  end

  def run
    git = Git::Git.new('git@github.com:Invoca/web.git', '/Users/mweaver/invoca/git-conflict-detector/tmp/cache/git/web')

    start_time = DateTime.now

    setup_repo(git)

    # get a list of branches and add them to the DB
    get_branch_list(git).each do |branch|
      Branch.create_from_git_data(branch)
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.branches_not_updated_since(start_time).destroy_all

    # get the list of branches that are new or have been updated since they were last tested
    untested_branches = Branch.untested_branches
    if untested_branches.empty?
      log_message("\nNo branches to process, exiting")
      return
    end
    log_message("\nBranches to process: #{untested_branches.join(', ')}")

    tested_pairs = []
    all_branches = Branch.all
    untested_branches.each do |branch|
      log_message("\nProcessing target branch: #{branch.name}")

      # exclude combinations we have already tested from the list
      branches_to_test = all_branches.select do |tested_branch|
        if tested_pairs.include?("#{branch.name}:#{tested_branch.name}")
          log_message("Skipping #{tested_branch.name}, already tested this combination")
          false
        else
          true
        end
      end

      # check this branch with the others to see if they conflict
      conflicts = get_conflicting_branch_names(git, branch, branches_to_test)

      branches_to_test.each do |tested_branch|
        # record or clear the conflict based on the test result
        if conflicts.include?(tested_branch.name)
          Conflict.create!(branch, tested_branch, start_time)
        else
          Conflict.clear!(branch, tested_branch, start_time)
        end

        # record the fact that we tested these branches
        tested_pairs << "#{branch.name}:#{tested_branch.name}"
        tested_pairs << "#{tested_branch.name}:#{branch.name}"
      end

      branch.mark_as_tested
    end

    # send notifications out
    send_conflict_emails(start_time)
  end
end

