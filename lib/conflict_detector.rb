require 'yaml'
require 'fileutils'
require_relative 'git'
require_relative '../environment'
require_relative '../models/branch'

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

  def call_git(git, command)
    log_message("Cmd: git #{command}")
    git.execute(command)
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
      raise "Need to fix path issue first!"
      #call_git(git, "clone #{git.repo_url}")
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
    log_message("\nProcessing target branch: #{target_branch_name}")

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
    git = Git::Git.new('git@github.com:Invoca/web.git', '/Users/mweaver/invoca/git-conflict-detector/.cache/web')

    start_time = DateTime.now

    setup_repo(git)

    # get a list of branches and add them to the DB
    get_branch_list(git).each do |branch|
      Branch.create_branch_from_git_data(branch)
    end

    # delete branches that were not updated by the git data
    # i.e. they have been deleted from git
    Branch.branches_not_updated_since(start_time).delete

    Branch.untested_branches.each do |branch|

    end
    # get list of all branches where modified > last_tested_at_date or last_tested_at_date is null
      # for each branch in list
        # test with another branch in the list
          # add conflict to DB or remove the conflict if there is none
        # add the branch pair to a new list
        # if the branch pair is in the list, then don't test it, prevents duplicate checks


    # purge deleted branches (where last_tested_at_date < now())
    # get list of conflicts where last_tested_at_date > now()
    # send notifications out





    log_message("\nBranches to process: #{branches.join', '}")

    get_conflicting_branch_names(git, '89/h/STORY-2989_White_Pages_Gender_Field', branches)
  end
end

