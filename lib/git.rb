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
    attr_reader :name, :last_modified_date, :author_email

    def initialize(name, last_modified_date, author_email)
      @name = name
      @last_modified_date = last_modified_date
      @author_email = author_email
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

    def execute(command)
      command = "#{GIT_PATH} #{command}"

      stdout_andstderr_str, status = Open3.capture2e(command, {chdir: @repo_path})
      unless status.success?
        raise GitError.new(command, status, stdout_andstderr_str)
      end

      stdout_andstderr_str
    end

    def get_branch_list
      raw_output = execute('for-each-ref refs/remotes/ --format=\'%(refname:short)~%(authordate:iso8601)\'')

      raw_output.split("\n").map! do |branch_and_date|
        branch_and_date = branch_and_date.split('~')
        branch_and_date = Branch.new(
            branch_and_date[0].sub!('origin/', ''),
            DateTime::parse(branch_and_date[1]),
            '')
      end
    end


    def self.get_conflict_list_from_failed_merge_output(failed_merged_output)
      failed_merged_output.split("\n").grep(/CONFLICT/).each do |conflict|
        conflict.sub!(/CONFLICT \(.*\): Merge conflict in /, '').sub!(/ deleted in .*/, '')
      end
    end

    def detect_conflicts(target_branch_name, source_branch_name)
      # attempt the merge and gather conflicts, if found
      begin
        execute("checkout #{source_branch_name}")
        execute("pull origin #{source_branch_name}")
        []
      rescue GitError => ex
        Git::get_conflict_list_from_failed_merge_output(ex.error_message)
      end
      # cleanup our "mess"
      execute("reset --hard origin/#{target_branch_name}")
    end
  end
end
