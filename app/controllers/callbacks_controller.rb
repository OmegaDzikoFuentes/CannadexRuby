class CallbacksController < ApplicationController
    skip_before_action :authenticate_user!
  
    # GET /callbacks/oauth/:provider
    def oauth
      provider = params[:provider]
      auth_data = request.env['omniauth.auth']
  
      user = User.find_or_create_from_oauth(auth_data, provider)
  
      if user.persisted?
        session[:user_id] = user.id
        redirect_to dashboard_path, notice: "Logged in with #{provider.capitalize}"
      else
        redirect_to login_path, alert: 'Authentication failed'
      end
    end
  
    # Failure callback for OmniAuth
    def failure
      redirect_to login_path, alert: 'Authentication failed: #{params[:message]}'
    end
  end