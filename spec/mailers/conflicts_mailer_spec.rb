require 'spec_helper'

RSpec.describe ConflictsMailer do
  before do
    ActionMailer::Base.deliveries = []
    @branches_a = create_test_branches(author_name: 'Author Name 1', author_email: 'author1@email.com')
    @branches_b = create_test_branches(author_name: 'Author Name 2', author_email: 'author2@email.com')
    @branches_c = create_test_branches(author_name: 'Author Name 3', author_email: 'author3@email.com')
  end

  context 'with conflict present' do
    before do
      @conflict_1 = create_test_conflict(
          @branches_a[0],
          @branches_b[0],
          file_list: ['file1.txt', 'file2.txt', 'file3.txt'])
    end

    it 'sends an email to users with conflicts' do
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          nil,
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(2)
      expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_a[0].author.email])
      expect(ActionMailer::Base.deliveries[1].to).to eq([@branches_b[0].author.email])
    end

    it 'sends an email to users with resolved conflicts' do
      @conflict_1.resolve!(Time.now)
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          nil,
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(2)
      expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_a[0].author.email])
      expect(ActionMailer::Base.deliveries[1].to).to eq([@branches_b[0].author.email])
    end

    it 'sends an email to override address' do
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          'override@email.com',
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(2)

      ActionMailer::Base.deliveries.each do |mail|
        expect(mail.to).to eq(['override@email.com'])
      end
    end

    it 'only sends email to users in filter list' do
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          ['author1@email.com', 'author3@email.com'],
          nil,
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(ActionMailer::Base.deliveries[0].to).to eq(['author1@email.com'])
    end

    it 'only sends email to users with new or resolved conflicts' do
      conflict_2 = create_test_conflict(
          @branches_a[1],
          @branches_b[1])
      conflict_2.resolve!(Time.now)

      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.from_now,
          [],
          nil,
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it 'excludes conflicts for users who own branches on exclusion list' do
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          nil,
          [@branches_a[0]],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      # should not email user A about the conflict because they own the branch on the exclusion list
      expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
    end

    it 'excludes resolved conflicts for users who own branches on exclusion list' do
      @conflict_1.resolve!(Time.now)
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          nil,
          [@branches_a[0]],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
      # should not email user A about the resolution because they own the branch on the exclusion list
      expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
    end

    context 'and with a branch suppression' do
      before do
        BranchNotificationSuppression.create!(@branches_a[0].author, @branches_a[0], nil)
      end

      it 'excludes conflicts for user who has the suppression' do
        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        # should not email user A about the conflict because they suppressed the branch in conflict
        expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
      end

      it 'excludes resolved conflicts for user who has the suppression' do
        @conflict_1.resolve!(Time.now)
        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        # should not email user A about the conflict because they suppressed the branch that was resolved
        expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
      end
    end

    context 'and with a conflict suppression' do
      before do
        ConflictNotificationSuppression.create!(@branches_a[0].author, @conflict_1, nil)
      end

      it 'excludes conflicts for user who has the conflict suppression' do
        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        # should not email user A about the conflict because they suppressed the conflict
        expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
      end

      it 'excludes resolved conflicts for users who has the conflict suppression' do
        @conflict_1.resolve!(Time.now)

        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            []) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        # should not email user A about the conflict because they suppressed the conflict that was resolved
        expect(ActionMailer::Base.deliveries[0].to).to eq([@branches_b[0].author.email])
      end
    end

    context 'sends an email that' do
      it 'contains the file list from the conflict' do
        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            []) }.to change { ActionMailer::Base.deliveries.count }.by(2)

        ActionMailer::Base.deliveries.each do |mail|
          expect(mail.text_part.to_s).to match(/.*Conflicts detected on updated branches.*/)
          expect(mail.text_part.to_s).not_to match(/.*Conflicts that have been resolved.*/)
          expect(mail.text_part.to_s).to match(/.*file1\.txt.*/)
          expect(mail.text_part.to_s).to match(/.*file2\.txt.*/)
          expect(mail.text_part.to_s).to match(/.*file3\.txt.*/)
          expect(mail.text_part.to_s).not_to match(/ignore list/)
          expect(mail.html_part.to_s).to match(/.*file1\.txt.*/)
          expect(mail.html_part.to_s).to match(/.*file2\.txt.*/)
          expect(mail.html_part.to_s).to match(/.*file3\.txt.*/)
          expect(mail.html_part.to_s).not_to match(/ignore list/)
        end
      end

      it 'excludes the files on the ignore list from the conflict' do
        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            ['file1.txt']) }.to change { ActionMailer::Base.deliveries.count }.by(2)

        ActionMailer::Base.deliveries.each do |mail|
          expect(mail.text_part.to_s).to match(/.*Conflicts detected on updated branches.*/)
          expect(mail.text_part.to_s).not_to match(/.*Conflicts that have been resolved.*/)
          expect(mail.text_part.to_s).not_to match(/.*file1\.txt.*/)
          expect(mail.text_part.to_s).to match(/.*file2\.txt.*/)
          expect(mail.text_part.to_s).to match(/.*file3\.txt.*/)
          expect(mail.text_part.to_s).to match(/and 1 file\(s\) on ignore list/)
          expect(mail.html_part.to_s).not_to match(/.*file1\.txt.*/)
          expect(mail.html_part.to_s).to match(/.*file2\.txt.*/)
          expect(mail.html_part.to_s).to match(/.*file3\.txt.*/)
          expect(mail.html_part.to_s).to match(/and 1 file\(s\) on ignore list/)
        end
      end

      it 'contains resolved conflicts' do
        @conflict_1.resolve!(Time.now)

        expect { ConflictsMailer.send_conflict_emails(
            'repo_name',
            1.hour.ago,
            [],
            nil,
            [],
            ['file1.txt']) }.to change { ActionMailer::Base.deliveries.count }.by(2)

        ActionMailer::Base.deliveries.each do |mail|
          expect(mail.text_part.to_s).not_to match(/.*Conflicts detected on updated branches.*/)
          expect(mail.text_part.to_s).to match(/.*Conflicts that have been resolved.*/)
        end
      end
    end
  end

  context 'without conflict present' do
    it 'does not send an email' do
      expect { ConflictsMailer.send_conflict_emails(
          'repo_name',
          1.hour.ago,
          [],
          nil,
          [],
          []) }.to change { ActionMailer::Base.deliveries.count }.by(0)
    end
  end
end
