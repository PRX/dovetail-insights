# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    include PrxAuth::Rails::Controller

    before_action :set_after_sign_in_path, :authenticate! # authenticate! is provided by prx_auth-rails
    before_action :authenticate_admin

    def authenticate_admin
      unless current_user.scopes.include?("prxadmin")
        render "errors/no_access", layout: "plain", status: :unauthorized
      end
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
