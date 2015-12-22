require 'spec_helper'

describe SuppressionsController, type: :controller do
  render_views

  context "with a conflict" do
    before do
      @branches_a = create_test_branches(author_name: 'Author A', count: 2)
      @branches_b = create_test_branches(author_name: 'Author B', count: 2)
      @conflict = create_test_conflict(@branches_a[0], @branches_b[1])
    end

    describe "GET new" do
      it "displays the conflicting branches" do
        response = get :new, conflict_id: @conflict.id, user_id: @conflict.branch_a.author.id
        expect(response.body).to match(Regexp.new(@conflict.branch_a.name))
        expect(response.body).to match(Regexp.new(@conflict.branch_b.name))
      end

      it "will not load if conflict is not owned by user" do
        other_user = User.create!(name: 'Another Author', email: 'another@email.com')
        expect { get :new, conflict_id: @conflict.id, user_id: other_user.id }.to raise_exception
      end

      it 'redirects to error page when the user is not found' do
        get :new, conflict_id: @conflict.id, user_id: 1000
        expect(response).to redirect_to(controller: 'errors', action: 'bad_request')
        expect(flash['alert']).not_to be_nil
      end

      it 'redirects to error page when the conflict is not found' do
        get :new, conflict_id: 1000, user_id: @conflict.branch_a.author.id
        expect(response).to redirect_to(controller: 'errors', action: 'bad_request')
        expect(flash['alert']).not_to be_nil
      end
    end

    describe "POST create" do
      it "creates a conflict suppression" do
        current_time = Time.now
        Timecop.freeze(current_time) do
          post :create, {
            conflict_id: @conflict.id,
            user_id: @conflict.branch_a.author.id,
            suppression: {
                'suppress_conflict' => '1',
                'suppression_duration_conflict' => SuppressionsController::SUPPRESSION_DURATION_ONE_WEEK
            }}

          suppressions = ConflictNotificationSuppression.all
          expect(suppressions.size).to eq(1)
          expect(suppressions[0].suppress_until.to_i).to eq(1.week.from_now.to_i)
          expect(suppressions[0].conflict.id).to eq(@conflict.id)
        end
      end

      it "creates a suppression for branch a" do
        current_time = Time.now
        Timecop.freeze(current_time) do
          post :create, {
                          conflict_id: @conflict.id,
                          user_id: @conflict.branch_a.author.id,
                          suppression: {
                              'suppress_branch_a' => '1',
                              'suppression_duration_branch_a' => SuppressionsController::SUPPRESSION_DURATION_ONE_WEEK
                          }}

          suppressions = BranchNotificationSuppression.all
          expect(suppressions.size).to eq(1)
          expect(suppressions[0].suppress_until.to_i).to eq(1.week.from_now.to_i)
          expect(suppressions[0].branch.id).to eq(@conflict.branch_a.id)
        end
      end

      it "creates a suppression for branch b" do
        current_time = Time.now
        Timecop.freeze(current_time) do
          post :create, {
                          conflict_id: @conflict.id,
                          user_id: @conflict.branch_a.author.id,
                          suppression: {
                              'suppress_branch_b' => '1',
                              'suppression_duration_branch_b' => SuppressionsController::SUPPRESSION_DURATION_ONE_WEEK
                          }}

          suppressions = BranchNotificationSuppression.all
          expect(suppressions.size).to eq(1)
          expect(suppressions[0].suppress_until.to_i).to eq(1.week.from_now.to_i)
          expect(suppressions[0].branch.id).to eq(@conflict.branch_b.id)
        end
      end

      it "will not allow creation of conflict if not owned by user" do
        other_user = User.create!(name: 'Another Author', email: 'another@email.com')
        expect { post :create, {
                        conflict_id: @conflict.id,
                        user_id: other_user.id,
                        suppression: {
                            'suppress_conflict' => '1',
                            'suppression_duration_conflict' => SuppressionsController::SUPPRESSION_DURATION_ONE_WEEK
                        }}}.to raise_exception
      end
    end

  end
end
