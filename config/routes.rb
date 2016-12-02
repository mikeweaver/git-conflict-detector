Rails.application.routes.draw do
  # respond to root for load balancer health checks
  get '/', to: proc { [200, {}, ['OK']] }

  get '/400' => 'errors#bad_request'

  get '/404' => 'errors#not_found'

  get '/500' => 'errors#internal_server_error'

  get 'users/:id/unsubscribe/new' => 'users#new_unsubscribe'
  post 'users/:id/unsubscribe/create' => 'users#create_unsubscribe'

  resources :suppressions, except: [:show, :edit, :update, :destroy]

  # catch all route
  match ':all' => 'errors#not_found', via: [:all]
end
