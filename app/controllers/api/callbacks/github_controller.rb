module Api
  module Callbacks
    class GithubController < ApplicationController
      protect_from_forgery with: :null_session
      before_filter :parse_request

      def push
        Rails.logger.info(
          "Received Github push callback. Adding to delayed job queue. Current queue depth: #{Delayed::Job.count}"
        )
        GithubPushHookHandler.new.queue!(@payload)
        render(nothing: true, status: :ok)
      end

      private

      def parse_request
        @payload = JSON.parse(request.body.read)
      rescue
        render(text: 'Invalid JSON', status: :bad_request)
      end
    end
  end
end
