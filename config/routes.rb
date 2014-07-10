Rails.application.routes.draw do
  namespace :sparkle do
    resources :stacks do
      member do
        get :events
        get :export
      end
      collection do
        get :status
        get :wait
      end
    end
  end
end
