Rails.application.routes.draw do

  namespace 'v1' do
    get 'symbols/:isin', to: "api#symbols"
    get 'historical_data/:period', to: "api#historical_data"
  end

  get 'app', to: 'webapp#home'

  root to: redirect('app')
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  match '*path', to: 'error#handle_not_found', via: :all
end
