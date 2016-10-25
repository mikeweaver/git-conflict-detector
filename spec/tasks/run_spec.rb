require 'spec_helper'
require 'rake'

describe 'run namespace rake task' do
  describe 'run:conflict_detector' do
    before do
      settings = OpenStruct.new(DEFAULT_CONFLICT_DETECTION_SETTINGS)
      settings.repository_name = 'repository_name'
      settings.default_branch_name = 'master'
      GlobalSettings.repositories_to_check_for_conflicts = { 'MyRepo' => settings }
    end

    let :run_rake_task do
      Rake.application.invoke_task('run:conflict_detector')
    end

    it 'calls the conflict detector for each repository' do
      conflict_detector = instance_double(ConflictDetector)
      expect(conflict_detector).to receive(:run)
      expect(ConflictDetector).to receive(:new).and_return(conflict_detector)
      run_rake_task
    end
  end

  describe 'run:auto_merger' do
    before do
      settings = OpenStruct.new(DEFAULT_AUTO_MERGE_SETTINGS)
      settings.repository_name = 'repository_name'
      settings.default_branch_name = 'master'
      settings.source_branch_name = 'master'
      GlobalSettings.branches_to_merge = { 'MyRepo-branch' => settings }
    end

    let :run_rake_task do
      Rake.application.invoke_task('run:auto_merger')
    end

    it 'calls the auto_merger for each repository' do
      auto_merger = instance_double(AutoMerger)
      expect(auto_merger).to receive(:run)
      expect(AutoMerger).to receive(:new).and_return(auto_merger)
      run_rake_task
    end
  end
end
