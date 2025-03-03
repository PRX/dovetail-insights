Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount PrxAuth::Rails::Engine => "/auth", :as => "prx_auth_engine"

  namespace :admin do
    resources :composition_result_metadata_logs

    root to: "composition_result_metadata_logs#index"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/data-explorer", to: "data_explorer#index", as: :data_explorer
  get "/data-explorer/export", to: "data_explorer#export"

  get "/.well-known/change-password", to: redirect("https://#{ENV["ID_HOST"]}/.well-known/change-password", status: 302)

  # Defines the root path route ("/")
  root "data_explorer#bookmarks"
end
