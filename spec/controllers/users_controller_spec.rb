require 'spec_helper'

describe UsersController, :type => :controller do
  describe "GET unsubscribe" do
    before do
      @user = User.create!(name: 'User', email: 'email@email.com')
    end

    it "unsubscribes the user" do
      get :unsubscribe, id: @user.id
      expect(@user.reload.unsubscribed).to be_truthy
    end

    it "renders the unsubscribe template" do
      get :unsubscribe, id: @user.id
      expect(response).to render_template("unsubscribe")
    end
  end
end
