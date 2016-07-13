require 'spec_helper'

describe Api::Callbacks::GithubController, type: :controller do
  render_views

  describe "POST #push" do
    it "returns success if valid JSON" do
      post :push, File.read(Rails.root.join('spec/fixtures/github_push.json'))
      expect(response).to have_http_status(200)
    end

    it "returns bad request if not valid JSON" do
      post :push, 'This is not JSON'
      expect(response).to have_http_status(400)
    end
  end

end
