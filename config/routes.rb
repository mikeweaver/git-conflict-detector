Rails.application.routes.default_url_options[:host] = GlobalSettings.web_server_url

Rails.application.routes.draw do
  get "/400" => "errors#bad_request"

  get "/404" => "errors#not_found"

  get "/500" => "errors#internal_server_error"

  get 'users/:id/unsubscribe' => 'users#unsubscribe'
  
  resources :suppressions, except: [:show, :edit, :update, :destroy]
end
