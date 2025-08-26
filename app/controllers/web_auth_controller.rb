class WebAuthController < ApplicationController
    skip_before_action :authenticate_user!, only: [:login, :register, :callback]
  
    # GET /auth/login
    def login
      render 'auth/login'
    end
  
    # POST /auth/login
    def perform_login
      # Similar to API login but set session
      user = User.find_by(email: params[:email])
      if user&.authenticate(params[:password])
        session[:user_id] = user.id
        redirect_to dashboard_path, notice: 'Logged in successfully'
      else
        flash[:alert] = 'Invalid credentials'
        render 'auth/login'
      end
    end
  
    # GET /auth/register
    def register
      @user = User.new
      render 'auth/register'
    end
  
    # POST /auth/register
    def perform_register
      @user = User.new(user_params)
      if @user.save
        session[:user_id] = @user.id
        redirect_to dashboard_path, notice: 'Registered successfully'
      else
        render 'auth/register'
      end
    end
  
    # GET /auth/callback (for OAuth)
    def callback
      # Handle OAuth callback, e.g., from Google or other providers
      auth_data = request.env['omniauth.auth']
      user = User.from_omniauth(auth_data)
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: 'Logged in with OAuth'
    end
  
    private
  
    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :date_of_birth)
    end
  end