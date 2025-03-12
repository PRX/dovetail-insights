# By default staging config matches production
require Rails.root.join("config/environments/production")

Rails.application.configure do
  # Override production config
end
