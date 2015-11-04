require 'open3'

module Git
  class GitError < StandardError
    attr_reader :command, :exit_code, :error_message

    def initialize(command, exit_code, error_message)
      @command = command
      @exit_code = exit_code
      @error_message = error_message
      super("Git command #{@command} failed with exit code #{@exit_code}. Message:\n#{@error_message}")
    end
  end

  class Branch
    attr_reader :name, :last_modified_date, :author_name, :author_email

    def initialize(name, last_modified_date, author_name, author_email)
      @name = name
      @last_modified_date = last_modified_date
      @author_email = author_email
      @author_name = author_name
    end

    def to_s
      @name
    end

    def =~(rhs)
      @name =~ rhs
    end
  end

  class Git

    GIT_PATH = '/usr/bin/git'.freeze

    attr_reader :repo_url, :repo_path

    def initialize(repo_url, repo_path)
      @repo_url = repo_url
      @repo_path = repo_path
    end

    def execute(command, run_in_repo_path=true)
      command = "#{GIT_PATH} #{command}"

      options = if run_in_repo_path
        {chdir: @repo_path}
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
        Branch.new(
            branch_data[0].sub!('origin/', ''),
            DateTime::parse(branch_data[1]),
            branch_data[2],
            branch_data[3].gsub!(/[<>]/,''))
      end
    end


    def self.get_conflict_list_from_failed_merge_output(failed_merged_output)
      failed_merged_output.split("\n").grep(/CONFLICT/).collect! do |conflict|
        conflict.sub(/CONFLICT \(.*\): /, '').sub(/Merge conflict in /, '').sub(/ deleted in .*/, '')
      end
    end

    def detect_conflicts(target_branch_name, source_branch_name)
      # attempt the merge and gather conflicts, if found
      begin
        # TODO: Assert we are actually on the target branch and have a clean working dir
        execute("pull --no-commit origin #{source_branch_name}")
        []
      rescue GitError => ex
        Git::get_conflict_list_from_failed_merge_output(ex.error_message)
      ensure
        # cleanup our "mess"
        execute("reset --hard origin/#{target_branch_name}")
      end
    end
  end
end
