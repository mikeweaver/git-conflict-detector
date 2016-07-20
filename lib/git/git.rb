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

    def merge_branches(target_branch_name, source_branch_name, source_tag_name: nil, keep_changes: true, commit_message: nil)
      if get_current_branch_name != target_branch_name
        checkout_branch(target_branch_name)
      end

      commit_message_argument = "-m \"#{commit_message.escape_double_quotes}\"" if commit_message
      if source_tag_name.present?
        source = Shellwords.escape(source_tag_name)
      else
        source = "origin/#{Shellwords.escape(source_branch_name)}"
      end

      raw_output = execute("merge --no-edit #{commit_message_argument} #{source}")

      if raw_output =~ /.*Already up-to-date.\n/
        [false, nil]
      else
        [true, nil]
      end
    rescue GitError => ex
      conflicting_files = Git::get_conflict_list_from_failed_merge_output(ex.error_message)
      unless conflicting_files.empty?
        [false,
         GitConflict.new(
            @repository_name,
            target_branch_name,
            source_branch_name,
            conflicting_files)]
      else
        raise
      end
    ensure
      # cleanup our "mess"
      keep_changes or reset
    end

    def clone_repository(default_branch_name)
      if Dir.exists?("#{@repository_path}")
        # cleanup any changes that might have been left over if we crashed while running
        reset
        execute('clean -f -d')

        # move to the master branch
        checkout_branch(default_branch_name)

        # remove branches that no longer exist on origin and update all branches that do
        execute('fetch --prune --all')

        # pull all of the branches
        execute('pull --all')
      else
        execute("clone #{@repository_url} #{@repository_path}", false)
      end
    end

    def push
      dry_run_argument = ''
      if GlobalSettings.dry_run
        dry_run_argument = '--dry-run'
      end
      raw_output = execute("push #{dry_run_argument} origin")
      raw_output != "Everything up-to-date\n"
    end

    def checkout_branch(branch_name)
      reset
      execute("checkout #{Shellwords.escape(branch_name)}")
      reset
    end

    def reset
      execute("reset --hard origin/#{Shellwords.escape(get_current_branch_name)}")
    end

    def lookup_tag(tag)
      execute("describe --abbrev=0 --match #{tag}").strip
    end

    def diff_branch_with_ancestor(branch_name, ancestor_branch_name)
      # gets the merge base of the branch and its ancestor, then gets a list of files changed since the merge base
      raw_output = execute("diff --name-only $(git merge-base origin/#{Shellwords.escape(ancestor_branch_name)} origin/#{Shellwords.escape(branch_name)})..origin/#{Shellwords.escape(branch_name)}")
      raw_output.split("\n")
    end

    def commits_diff_branch_with_ancestor(branch_name, ancestor_branch_name)
      raw_output = execute("log --format=$'%H\t%an\t%ae\t%aI\t%s' --no-color origin/#{Shellwords.escape(ancestor_branch_name)}..origin/#{Shellwords.escape(branch_name)}")
      raw_output.split("\n").map do |row|
        commit_data = row.split("\t")
        GitCommit.new(commit_data[0], commit_data[4], DateTime::parse(commit_data[3]), commit_data[1], commit_data[2])
      end
    end

    def get_current_branch_name
      execute('rev-parse --abbrev-ref HEAD').strip
    end

    private

    def self.get_conflict_list_from_failed_merge_output(failed_merged_output)
      failed_merged_output.split("\n").grep(/CONFLICT/).collect! do |conflict|
        conflict.sub(/CONFLICT \(.*\): /, '').sub(/Merge conflict in /, '').sub(/ deleted in .*/, '')
      end
    end
  end
end
