require 'yaml'
require 'fileutils'
require_relative 'git'
require_relative '../app/models/branch'

# TODO: Cache results and suppress duplicate warnings
# TODO: Cache results and skip merges that are already known failures
# TODO: OO this thing, its a mess

class ConflictDetector

  DEFAULT_SETTINGS = {
    log_directory: '.logs',
    cache_directory: '.cache',
    log_file: ".logs/git.log",
    maximum_branches_to_check: 100,
    repos_to_check: ['Invoca/web'],
    ignore_branches: [], #regex
    ignore_branches_modified_days_ago: 3,
    only_branches: ['^89/.*$', 'master'], #regex
    ignore_conflicts_in_file_paths: ['^db/schema.sql$', '^test/fixtures/.*$', '^lib/data/generated/.*$'], #regex
    master_branch_name: 'master'
  }.freeze

  def initialize(settings_file_path='settings.yml')
    if File.exists?(settings_file_path)
      @settings = DEFAULT_SETTINGS.clone.merge(YAML.load(File.read(settings_file_path)))
    else
      @settings = DEFAULT_SETTINGS.clone
    end

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

      # remove all local branches, if there are any
      #if call_git(git, 'branch | grep -v \*')
      #  call_git(git, 'branch -D `git branch | grep -v \* | xargs`')
      #end

      # remove branches that no longer exist on origin and update all branches that do
      call_git(git, 'fetch --prune --all')
    else
      call_git(git, "clone #{git.repo_url} #{git.repo_path}", false)
    end
  end

  def get_branch_list(git)
    branches = git.get_branch_list

    branches.delete_if do |branch|
      if should_ignore_branch_by_list?(branch)
        log_message("Skipping branch #{branch}, it is on the ignore list")
        true
      elsif !should_include_branch?(branch)
        log_message("Skipping branch #{branch}, it is not on the include list")
        true
      elsif should_ignore_branch_by_date?(branch)
        log_message("Skipping branch #{branch}, it has not been modified in over #{@settings[:ignore_branches_modified_days_ago]} days")
        true
      else
        false
      end
    end
  end

  def get_conflicting_branch_names(git, target_branch_name, source_branch_names)
    conflicting_branch_names = []
    branches_checked = 0
    source_branch_names.each do |source_branch_name|
      # break if we have tested enough branches already
      branches_checked += 1
      if @settings[:maximum_branches_to_check] && (branches_checked > @settings[:maximum_branches_to_check])
        log_message("WARNING: Checked the maximum number of branches allowed, #{@settings[:maximum_branches_to_check]}, exiting early")
        break
      end

      # don't try to merge the branch with itself
      next if target_branch_name == source_branch_name

      log_message("Attempt to merge #{source_branch_name}")
      conflicts = git.detect_conflicts(target_branch_name, source_branch_name)
      log_message("SUCCESS: #{source_branch_name} can be merged into #{target_branch_name} without conflicts")
      if conflicts
        if should_ignore_conflicts?(conflicts)
          log_message("#{target_branch_name} conflicts with #{source_branch_name}, but all conflicting files are on the ignore list.")
        else
          log_message("WARNING: #{target_branch_name} conflicts with #{source_branch_name}\nConflicting files:\n#{conflicts}")
          conflicting_branch_names << source_branch_name
        end
      end
    end

    conflicting_branch_names
  end

  def run
    git = Git::Git.new('git@github.com:Invoca/web.git', '/Users/mweaver/invoca/git-conflict-detector/tmp/cache/git/web')

    start_time = DateTime.now

    setup_repo(git)

    # get a list of branches and add them to the DB
    get_branch_list(git).each do |branch|
      Branch.create_branch_from_git_data(branch)
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.branches_not_updated_since(start_time).destroy_all

    branches = Branch.untested_branches
    log_message("\nBranches to process: #{branches.join(', ')}")

    tested_pairs = []
    branches.each do |branch|
      log_message("\nProcessing target branch: #{branch}")

      # exclude combinations we have already tested from the list
      branches_to_test = branches.select do |tested_branch|
        if tested_pairs.include?("#{branch}:#{tested_branch}")
          log_message("Skipping #{tested_branch}, already tested this combination")
          false
        else
          true
        end
      end

      # check this branch with the others to see if they conflict
      conflicts = get_conflicting_branch_names(git, branch, branches_to_test)

      branches_to_test.each do |tested_branch|
        # record or clear the conflict based on the test result
        if conflicts.include?(tested_branch.to_s)
          branch.create_conflict(tested_branch, start_time)
        else
          branch.clear_conflict(tested_branch)
        end

        # record the fact that we tested these branches
        tested_pairs << "#{branch}:#{tested_branch}"
        tested_pairs << "#{tested_branch}:#{branch}"
      end
    end

    # get list of conflicts where last_tested_at_date > now()
    # send notifications out
  end
end

