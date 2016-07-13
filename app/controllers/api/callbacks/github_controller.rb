module Api
  module Callbacks
    class GithubController < ApplicationController
      protect_from_forgery with: :null_session
      before_filter :parse_request

      def push
        puts @json
        render(nothing: true, status: :ok)
      end

      private

      def parse_request
        @json = JSON.parse(request.body.read)
      rescue
        render(text: 'Invalid JSON', status: :bad_request)
      end
    end
  end
end
