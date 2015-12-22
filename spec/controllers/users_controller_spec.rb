require 'spec_helper'

describe UsersController, type: :controller do
  render_views

  describe "GET new unsubscribe" do
    before do
      @user = User.create!(name: 'User', email: 'email@email.com')
    end

    it "renders the unsubscribe template" do
      get :new_unsubscribe, id: @user.id
      expect(response).to render_template("new_unsubscribe")
    end

    it 'redirects to error page when the user is not found' do
      get :new_unsubscribe, id: @user.id + 1
      expect(response).to redirect_to(controller: 'errors', action: 'bad_request')
      expect(flash['alert']).not_to be_nil
    end
  end

  describe "POST create unsubscribe" do
    before do
      @user = User.create!(name: 'User', email: 'email@email.com')
    end

    it "unsubscribes the user" do
      post :create_unsubscribe, id: @user.id
      expect(@user.reload.unsubscribed).to be_truthy
    end

    it "renders the unsubscribe success template" do
      get :create_unsubscribe, id: @user.id
      expect(response).to render_template("create_unsubscribe")
    end
  end
end
