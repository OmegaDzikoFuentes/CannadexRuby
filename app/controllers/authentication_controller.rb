class AuthenticationController < ApplicationController
    skip_before_action :authenticate_user!, only: [:register, :login, :verify_age]
  
    # POST /auth/register
    def register
      @user = User.new(user_registration_params)
  
      if @user.save
        # Send age verification email or trigger process
        UserMailer.age_verification(@user).deliver_later
  
        render json: {
          message: 'User registered successfully. Please verify your age.',
          user: user_auth_json(@user),
          token: generate_jwt_token(@user)
        }, status: :created
      else
        render json: {
          error: 'Registration failed',
          errors: @user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end
  
    # POST /auth/login
    def login
      @user = User.find_by(email: params[:email].downcase)
  
      if @user&.authenticate(params[:password])
        unless @user.age_verified?
          return render json: { error: 'Age not verified' }, status: :forbidden
        end
  
        render json: {
          message: 'Login successful',
          user: user_auth_json(@user),
          token: generate_jwt_token(@user)
        }
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    end
  
    # POST /auth/verify_age
    def verify_age
      @user = User.find_by(verification_token: params[:token])
  
      if @user
        @user.update!(
          age_verified: true,
          age_verified_at: Time.current,
          verification_token: nil
        )
  
        render json: { message: 'Age verified successfully' }
      else
        render json: { error: 'Invalid verification token' }, status: :not_found
      end
    end
  
    # POST /auth/logout (client-side token invalidation)
    def logout
      # Since JWT is stateless, logout is handled client-side by removing token
      # Optionally, implement token blacklisting here if needed
      render json: { message: 'Logout successful' }
    end
  
    private
  
    def user_registration_params
      params.require(:user).permit(
        :first_name, :last_name, :username, :email,
        :password, :password_confirmation, :date_of_birth
      )
    end
  
    def user_auth_json(user)
      {
        id: user.id,
        username: user.username,
        email: user.email,
        age_verified: user.age_verified?,
        level: user.level
      }
    end
  
    def generate_jwt_token(user)
      JWT.encode(
        { user_id: user.id, exp: 24.hours.from_now.to_i },
        Rails.application.credentials.secret_key_base
      )
    end
  end