# app/controllers/api/v1/application_controller.rb
class Api::V1::ApplicationController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    
    before_action :authenticate_user!
    before_action :ensure_age_verified
    
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request
    
    protected
    
    def authenticate_user!
      authenticate_with_http_token do |token, _options|
        @current_user = User.find_by(api_token: token)
      end
      
      render_unauthorized unless @current_user
    end
    
    def current_user
      @current_user
    end
    
    def ensure_age_verified
      return if @current_user&.age_verified?
      
      render json: {
        error: 'Age verification required',
        code: 'AGE_VERIFICATION_REQUIRED'
      }, status: :forbidden
    end
    
    def render_success(data = {}, message = 'Success')
      render json: {
        success: true,
        message: message,
        data: data
      }
    end
    
    def render_error(message, status = :unprocessable_entity, code = nil)
      render json: {
        success: false,
        message: message,
        code: code
      }, status: status
    end
    
    private
    
    def not_found
      render json: { success: false, message: 'Record not found' }, status: :not_found
    end
    
    def unprocessable_entity(exception)
      render json: {
        success: false,
        message: 'Validation failed',
        errors: exception.record.errors
      }, status: :unprocessable_entity
    end
    
    def bad_request
      render json: { success: false, message: 'Bad request' }, status: :bad_request
    end
    
    def render_unauthorized
      render json: { success: false, message: 'Unauthorized' }, status: :unauthorized
    end
  end