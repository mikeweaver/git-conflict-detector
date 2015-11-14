require 'spec_helper'

describe 'Git' do

  def create_mock_open_status(status)
    status_object = double()
    allow(status_object).to receive(:success?) { status == 1 }
    allow(status_object).to receive(:to_s) { status.to_s }
    return status_object
  end

  def mock_execute(stdout_andstderr_str, status)
    # mock the call and repsonse to execute the git command
    expect(Open3).to receive(:capture2e).exactly(1).times.and_return([stdout_andstderr_str, create_mock_open_status(status)])
  end

  it 'can be created' do
    git = Git::Git.new('repo_url', 'repo_path')

    expect(git.repo_url).to eq('repo_url')
    expect(git.repo_path).to eq('repo_path')
  end

  context 'with a git repo' do

    before do
      @git = Git::Git.new('repo_url', 'repo_path')
    end

    it 'can execute a command' do
      mock_execute('sample output', 1)
      expect(@git.execute('sample command')).to eq('sample output')
    end

    it 'raises GitError when a command fails' do
      mock_execute('sample output', 0)
      expect{@git.execute('sample command')}.to raise_exception(Git::GitError)
    end

    it 'can parse a branch list' do
      mock_execute(
          "origin/test_1~2015-10-19 17:58:24 -0700~Nicholas Ellis~<nellis@invoca.com>\norigin/test_build~2015-10-19 15:03:22 -0700~Bob Smith~<bob@invoca.com>\norigin/test_build_b~2015-10-19 16:52:40 -0700~Nicholas Ellis~<nellis@invoca.com>",
          1)

      branch_list = []
      branch_list << Git::Branch.new(
          'test_1',
          DateTime::parse('2015-10-19 17:58:24 -0700'),
          'Nicholas Ellis',
          'nellis@invoca.com')
      branch_list << Git::Branch.new(
          'test_build',
          DateTime::parse('2015-10-19 15:03:22 -0700'),
          'Bob Smith',
          'bob@invoca.com')
      branch_list << Git::Branch.new(
          'test_build_b',
          DateTime::parse('2015-10-19 16:52:40 -0700'),
          'Nicholas Ellis',
          'nellis@invoca.com')

      expect(@git.get_branch_list).to eq(branch_list)
    end

    it 'can detect conflicts between branches' do
      expect(Open3).to receive(:capture2e).exactly(2).times.and_return(
         ["From github.com:/Invoca/web\n" +
              " * branch            85/t/trello_adwords_dashboard_tiles_auto_adjust_font_size -> FETCH_HEAD\n" +
              "warning: Cannot merge binary files: test/fixtures/whitepages.sql (HEAD vs. fedc8e0cfa136d5e1f84005ab6d82235122b0006)\n" +
              "Auto-merging test/workers/adwords_detail_worker_test.rb\n" +
              "CONFLICT (content): Merge conflict in test/workers/adwords_detail_worker_test.rb\n" +
              "CONFLICT (modify/delete): pegasus/backdraft/pegasus_dashboard/spec/views/call_cost_tile_spec.js deleted in fedc8e0cfa136d5e1f84005ab6d82235122b0006 and modified in HEAD. Version HEAD of pegasus/backdraft/pegasus_dashboard/spec/views/call_cost_tile_spec.js left in tree.\n" +
              "    Auto-merging pegasus/backdraft/dist/pegasus_dashboard.js\n" +
              "Automatic merge failed; fix conflicts and then commit the result.",
          create_mock_open_status(0)],
         ['ingored output', create_mock_open_status(1)])

      conflict = Git::Conflict.new(
          '91/eb/WEB-1723_Ringswitch_DB_Conn_Loss',
          '85/t/trello_adwords_dashboard_tiles_auto_adjust_font_size',
          ['test/workers/adwords_detail_worker_test.rb', 'pegasus/backdraft/pegasus_dashboard/spec/views/call_cost_tile_spec.js'])
      expect(@git.detect_conflicts(
                 '91/eb/WEB-1723_Ringswitch_DB_Conn_Loss',
                 '85/t/trello_adwords_dashboard_tiles_auto_adjust_font_size')).to eq(conflict)
    end

    it 'can return nil if no conflicts between branches are found' do
      expect(Open3).to receive(:capture2e).and_return(
                           ["From github.com:/Invoca/web\n" +
                                " * branch            85/t/trello_adwords_dashboard_tiles_auto_adjust_font_size -> FETCH_HEAD\n" +
                                "Auto-merging test/workers/adwords_detail_worker_test.rb\n" +
                                "    Auto-merging pegasus/backdraft/dist/pegasus_dashboard.js\n",
                            create_mock_open_status(0)],
                           ['ingored output', create_mock_open_status(1)])

      expect(@git.detect_conflicts(
                 '91/eb/WEB-1723_Ringswitch_DB_Conn_Loss',
                 '85/t/trello_adwords_dashboard_tiles_auto_adjust_font_size')).to eq(nil)
    end
  end
end
