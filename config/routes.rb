Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # PDF Documents routes (read-only, no upload)
  resources :pdf_documents, only: [:index, :show, :destroy] do
    member do
      patch :reprocess
      get :reprocess
      get :data_view
    end
  end
  root 'pdf_documents#index'

  # Data export routes
  namespace :data_exports do
    get :index
    get :export_csv
    get :export_excel
    get :export_filtered
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
