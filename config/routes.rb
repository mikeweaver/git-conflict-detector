Rails.application.routes.draw do
  get '/400' => 'errors#bad_request'

  get '/404' => 'errors#not_found'

  get '/500' => 'errors#internal_server_error'

  get 'users/:id/unsubscribe/new' => 'users#new_unsubscribe'
  post 'users/:id/unsubscribe/create' => 'users#create_unsubscribe'

  resources :suppressions, except: [:show, :edit, :update, :destroy]
end
