module PrxAuthHelper
  ##
  # Boolean indicating if the current user has acces to the given app

  def current_user_app?(name)
    current_user && current_user_app(name).present?
  end

  ##
  # If the current user has access to an app with a name like the one
  # provided, return the URL for that app

  def current_user_app(name)
    current_user_apps.filter_map do |key, url|
      url if key.downcase.include?(name)
    end.first
  end
end
