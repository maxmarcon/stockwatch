Rails.application.routes.draw do

  namespace 'v1' do
    namespace 'api', path: '/' do
      get 'test'
    end
  end

  get 'app', to: 'webapp#home'

  root to: redirect('app')
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
