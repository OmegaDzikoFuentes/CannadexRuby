# app/controllers/admin/application_controller.rb
class Admin::ApplicationController < ApplicationController
    before_action :ensure_admin
    
    protected
    
    def ensure_admin
      unless current_user&.admin?
        render json: { error: 'Admin access required' }, status: :forbidden
      end
    end
    
    def current_user
      @current_user ||= User.find_by(api_token: request.headers['Authorization']&.split(' ')&.last)
    end
  end