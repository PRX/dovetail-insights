Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  prx_auth_routes

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
  get "/data-explorer/sql", to: "data_explorer#sql"

  get "typeahead/cities", to: "typeahead#cities", as: :cities_typeahead
  get "relatime/to_abs", to: "relatime#to_abs", as: :relatime_to_abs

  get "/.well-known/change-password", to: redirect("https://#{ENV["ID_HOST"]}/.well-known/change-password", status: 302)

  # Defines the root path route ("/")
  root "data_explorer#bookmarks"
end
