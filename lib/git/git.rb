require 'open3'

module Git
  class Git

    GIT_PATH = '/usr/bin/git'.freeze

    attr_reader :repository_url, :repository_path

    def initialize(repository_name)
      @repository_name = repository_name
      @repository_url = "git@github.com:#{repository_name}.git"
      @repository_path = "#{File.join(GlobalSettings.cache_directory, repository_name)}"
    end

    def execute(command, run_in_repository_path=true)
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

    def detect_conflicts(target_branch_name, source_branch_name)
      # attempt the merge and gather conflicts, if found
      begin
        # TODO: Assert we are actually on the target branch and have a clean working dir
        execute("pull --no-commit origin #{source_branch_name}")
        nil
      rescue GitError => ex
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
        execute("reset --hard origin/#{target_branch_name}")
      end
    end

    private

    def self.get_conflict_list_from_failed_merge_output(failed_merged_output)
      failed_merged_output.split("\n").grep(/CONFLICT/).collect! do |conflict|
        conflict.sub(/CONFLICT \(.*\): /, '').sub(/Merge conflict in /, '').sub(/ deleted in .*/, '')
      end
    end
  end
end
