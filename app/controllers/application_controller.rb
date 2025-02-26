class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate! # authenticate! is provided by prx_auth-rails
  before_action :current_user_podcast_accounts

  protected

  def authenticate!
    if super == true
      # Because config.namespace is set, these checks look in the :insights
      # namespace (aka app) by default. Anyone with read-private permissions
      # to Insights will be allowed to use the app
      unless current_user.globally_authorized?(:read_private) || current_user.authorized_account_ids(:read_private).any?
        render "errors/no_access", layout: "plain"
      end
    end
  end

  def current_user_podcast_accounts
    return [] unless current_user

    # For the time being, there are no resource-level permissions for Insights,
    # so we're piggybacking off some Feeder and Augury permissions to determine
    # which podcasts people should see in Insights
    @current_user_podcast_accounts ||= (current_user.resources(:feeder, :read_private) + current_user.resources(:augury, :campaign))
  end
end
