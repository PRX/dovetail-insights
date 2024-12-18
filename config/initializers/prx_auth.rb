PrxAuth::Rails.configure do |config|
  config.install_middleware = true
  config.namespace = :insights
  config.prx_client_id = ENV["PRX_CLIENT_ID"]
  config.id_host = ENV["ID_HOST"] || ""
end
