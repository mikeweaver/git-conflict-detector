require 'spec_helper'

describe MergeMailer do
  before do
    ActionMailer::Base.deliveries = []
    @branches_a = GitModels::TestHelpers.create_branches(
      author_name: 'Author Name 1',
      author_email: 'author1@email.com'
    )
    @branches_b = GitModels::TestHelpers.create_branches(
      author_name: 'Author Name 2',
      author_email: 'author2@email.com'
    )
    @branches_c = GitModels::TestHelpers.create_branches(
      author_name: 'Author Name 3',
      author_email: 'author3@email.com'
    )
  end

  context 'with successful merge present' do
    before do
      @merge_1 = create_test_merge(
        @branches_a[0],
        @branches_b[0]
      )
    end

    it 'sends an email to users with merges' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries[0].to).to eq([@merge_1.target_branch.author.email])
    end

    it 'sends an email to override address' do
      allow(GlobalSettings).to receive(:email_override).and_return('override@email.com')

      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries[0].to).to eq(['override@email.com'])
    end

    it 'only sends email to users in filter list' do
      @merge_2 = create_test_merge(
        @branches_c[0],
        @branches_a[0]
      )
      allow(GlobalSettings).to receive(:email_filter).and_return(['author2@email.com', 'author3@email.com'])

      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries[0].to).to eq([@merge_1.target_branch.author.email])
    end

    it 'only sends email to subscribed' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)

      ActionMailer::Base.deliveries = []

      @merge_1.target_branch.author.unsubscribe!

      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it 'only sends email to users with new merges' do
      create_test_merge(
        @branches_a[1],
        @branches_b[1],
        successful: false
      )

      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.from_now) }.to \
        change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it 'sends an email that contains successful merges' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)

      ActionMailer::Base.deliveries.each do |mail|
        expect(mail.html_part.to_s).to match(/.*Successful Merges.*/)
        expect(mail.html_part.to_s).not_to match(/.*Unsuccessful Merges.*/)
        expect(mail.text_part.to_s).to match(/.*Successful Merges.*/)
        expect(mail.text_part.to_s).not_to match(/.*Unsuccessful Merges.*/)
      end
    end
  end

  context 'with unsuccessful merge present' do
    before do
      @merge_1 = create_test_merge(
        @branches_a[0],
        @branches_b[0],
        successful: false
      )
    end

    it 'sends an email to users with unsuccessful merges' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries[0].to).to eq([@merge_1.target_branch.author.email])
    end

    it 'sends an email that contains unsuccessful merges' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)

      ActionMailer::Base.deliveries.each do |mail|
        expect(mail.html_part.to_s).not_to match(/.*Successful Merges.*/)
        expect(mail.html_part.to_s).to match(/.*Unsuccessful Merges.*/)
        expect(mail.text_part.to_s).not_to match(/.*Successful Merges.*/)
        expect(mail.text_part.to_s).to match(/.*Unsuccessful Merges.*/)
      end
    end
  end

  context 'with successful and unsuccessful merge present' do
    before do
      @merge_1 = create_test_merge(
        @branches_a[0],
        @branches_b[0],
        successful: true
      )
      @merge_2 = create_test_merge(
        @branches_c[0],
        @branches_b[0],
        successful: false
      )
    end

    it 'sends an email that contains successful and unsuccessful merges' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(1)

      ActionMailer::Base.deliveries.each do |mail|
        expect(mail.html_part.to_s).to match(/.*Successful Merges.*/)
        expect(mail.html_part.to_s).to match(/.*Unsuccessful Merges.*/)
        expect(mail.text_part.to_s).to match(/.*Successful Merges.*/)
        expect(mail.text_part.to_s).to match(/.*Unsuccessful Merges.*/)
      end
    end
  end

  context 'without merge present' do
    it 'does not send an email' do
      expect { MergeMailer.send_merge_emails('repository_name', 1.hour.ago) }.to \
        change { ActionMailer::Base.deliveries.count }.by(0)
    end
  end
end
