# app/controllers/api/v1/authentication_controller.rb
class Api::V1::AuthenticationController < Api::V1::ApplicationController
    skip_before_action :authenticate_user!, only: [:login, :register, :forgot_password, :reset_password]
    skip_before_action :ensure_age_verified, only: [:login, :register, :verify_age, :forgot_password, :reset_password]
    
    def register
      user = User.new(registration_params)
      
      if user.save
        render_success(
          {
            user: user_data(user),
            token: user.api_token
          },
          'Registration successful'
        )
      else
        render json: {
          success: false,
          message: 'Registration failed',
          errors: user.errors
        }, status: :unprocessable_entity
      end
    end
    
    def login
      user = User.find_by(email: params[:email]&.downcase)
      
      if user&.authenticate(params[:password])
        render_success(
          {
            user: user_data(user),
            token: user.api_token,
            age_verified: user.age_verified?
          },
          'Login successful'
        )
      else
        render_error('Invalid email or password', :unauthorized)
      end
    end
    
    def logout
      # In a stateless JWT setup, you'd typically blacklist the token
      # For API tokens, we can regenerate it to invalidate the current one
      current_user.update!(api_token: SecureRandom.hex(20))
      render_success({}, 'Logged out successfully')
    end
    
    def verify_age
      date_of_birth = Date.parse(params[:date_of_birth]) rescue nil
      
      if date_of_birth.nil?
        render_error('Invalid date of birth')
        return
      end
      
      age = ((Date.current - date_of_birth) / 365.25).floor
      
      if age >= 21
        current_user.update!(
          date_of_birth: date_of_birth,
          age_verified: true,
          age_verified_at: Time.current
        )
        render_success({ age_verified: true }, 'Age verified successfully')
      else
        render_error('Must be 21 or older to use Cannadex', :forbidden)
      end
    end
    
    def forgot_password
      user = User.find_by(email: params[:email]&.downcase)
      
      if user
        # Generate reset token and send email
        user.update!(
          reset_password_token: SecureRandom.urlsafe_base64,
          reset_password_sent_at: Time.current
        )
        
        # Send email (implement UserMailer.password_reset)
        UserMailer.password_reset(user).deliver_later
      end
      
      # Always return success for security
      render_success({}, 'If email exists, password reset instructions have been sent')
    end
    
    def reset_password
      user = User.find_by(
        reset_password_token: params[:token],
        reset_password_sent_at: 4.hours.ago..Time.current
      )
      
      if user&.update(password: params[:password], password_confirmation: params[:password_confirmation])
        user.update!(reset_password_token: nil, reset_password_sent_at: nil)
        render_success({}, 'Password reset successful')
      else
        render_error('Invalid or expired reset token', :unprocessable_entity)
      end
    end
    
    private
    
    def registration_params
      params.permit(:first_name, :last_name, :username, :email, :password, :password_confirmation, :phone, :bio)
    end
    
    def user_data(user)
      {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        username: user.username,
        email: user.email,
        bio: user.bio,
        level: user.level,
        experience_points: user.experience_points,
        total_encounters: user.total_encounters,
        battles_won: user.battles_won,
        battles_lost: user.battles_lost,
        win_rate: user.win_rate,
        age_verified: user.age_verified?,
        created_at: user.created_at
      }
    end
  end