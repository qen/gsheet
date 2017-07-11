Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # omniauth callback url
  get '/auth/:provider/callback', to: 'authentications#google'

  resources :campaigns, only: %i(update)

  root to: 'visitors#home'
end
