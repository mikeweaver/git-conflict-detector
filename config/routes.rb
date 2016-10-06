Rails.application.routes.default_url_options[:host] = GlobalSettings.web_server_url

Rails.application.routes.draw do
  get "/400" => "errors#bad_request"

  get "/404" => "errors#not_found"

  get "/500" => "errors#internal_server_error"

  get 'users/:id/unsubscribe/new' => 'users#new_unsubscribe'
  post 'users/:id/unsubscribe/create' => 'users#create_unsubscribe'
  
  resources :suppressions, except: [:show, :edit, :update, :destroy]

  namespace 'jira' do
    namespace 'status' do
      resources :push, only: [:edit, :update]
    end
  end

  namespace 'api' do
    scope '/v1' do
      namespace 'callbacks' do
        scope '/github' do
            post '/push' => 'github#push'
        end
      end
    end
  end
end
