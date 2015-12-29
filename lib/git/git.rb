require 'open3'

module Git
  class Git

    GIT_PATH = '/usr/bin/git'.freeze

    attr_reader :repository_name, :repository_url, :repository_path

    def initialize(repository_name)
      @repository_name = repository_name
      @repository_url = "git@github.com:#{repository_name}.git"
      @repository_path = "#{File.join(GlobalSettings.cache_directory, repository_name)}"
    end

    def execute(command, run_in_repository_path=true)
      Rails.logger.debug("git #{command}")
      command = "#{GIT_PATH} #{command}"

      options = if run_in_repository_path
        {chdir: @repository_path}
      else
        {}
      end
      stdout_andstderr_str, status = Open3.capture2e(command, options)
      unless status.success?
        raise GitError.new(command, status, stdout_andstderr_str)
      end

      stdout_andstderr_str
    end

    def get_branch_list
      raw_output = execute('for-each-ref refs/remotes/ --format=\'%(refname:short)~%(authordate:iso8601)~%(authorname)~%(authoremail)\'')

      raw_output.split("\n").collect! do |raw_branch_data|
        branch_data = raw_branch_data.split('~')
        GitBranch.new(
            @repository_name,
            branch_data[0].sub!('origin/', ''),
            DateTime::parse(branch_data[1]),
            branch_data[2],
            branch_data[3].gsub!(/[<>]/,''))
      end
    end

    def detect_conflicts(target_branch_name, source_branch_name, keep_changes: false)
      # attempt the merge and gather conflicts, if found
      begin
        # TODO: Assert we are actually on the target branch and have a clean working dir
        execute("pull --no-commit origin #{source_branch_name}")
        nil
      rescue GitError => ex
        keep_changes = false
        conflicting_files = Git::get_conflict_list_from_failed_merge_output(ex.error_message)
        unless conflicting_files.empty?
          GitConflict.new(
              @repository_name,
              target_branch_name,
              source_branch_name,
              conflicting_files)
        else
          nil
        end
      ensure
        # cleanup our "mess"
        keep_changes or execute("reset --hard origin/#{target_branch_name}")
      end
    end

    def clone_repository(default_branch)
      if Dir.exists?("#{@repository_path}")
        # cleanup any changes that might have been left over if we crashed while running
        execute('reset --hard origin')
        execute('clean -f -d')

        # move to the master branch
        execute("checkout #{default_branch}")

        # remove branches that no longer exist on origin and update all branches that do
        execute('fetch --prune --all')

        # pull all of the branches
        execute('pull --all')
      else
        execute("clone #{@repository_url} #{@repository_path}", false)
      end
    end

    def push()
      dry_run_argument = ''
      if GlobalSettings.dry_run
        dry_run_argument = '--dry-run'
      end
      raw_output = execute("push #{dry_run_argument} origin")
      raw_output != "Everything up-to-date\n"
    end

    def checkout_branch(branch_name)
      execute("checkout #{branch_name}")
      execute("reset --hard origin/#{branch_name}")
    end

    private

    def self.get_conflict_list_from_failed_merge_output(failed_merged_output)
      failed_merged_output.split("\n").grep(/CONFLICT/).collect! do |conflict|
        conflict.sub(/CONFLICT \(.*\): /, '').sub(/Merge conflict in /, '').sub(/ deleted in .*/, '')
      end
    end
  end
end
