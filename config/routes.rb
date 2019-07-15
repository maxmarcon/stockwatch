Rails.application.routes.draw do

  namespace 'v1' do
    get 'isin/:isin', to: "api#isin"
    get 'chart/:period', to: "api#chart"
  end

  get 'app', to: 'webapp#home'

  root to: redirect('app')
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  match '500', to: 'error#handle_internal_error', via: :all
  match '404', to: 'error#handle_not_found', via: :all
  match '400', to: 'error#handle_bad_request', via: :all

  match '*path', to: 'error#handle_not_found', via: :all
end
