class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from CanCan::AccessDenied, with: :access_denied

  # JSON response helpers
  def render_success(data = {}, status = :ok)
    render json: { success: true, data: data }, status: status
  end

  def render_error(message, errors = [], status = :unprocessable_entity)
    render json: { success: false, error: message, errors: errors }, status: status
  end


  def authenticate_user!
    head :unauthorized unless current_user
  end

  def current_user
    @current_user ||= User.find_by(api_token: request.headers['Authorization']&.split(' ')&.last)
  end

  helper_method :current_user
  private

  def record_not_found(exception)
    render_error('Record not found', [], :not_found)
    Rails.logger.error "RecordNotFound: #{exception.message}"
  end

  def access_denied(exception)
    render_error('Access denied', [], :forbidden)
    Rails.logger.error "AccessDenied: #{exception.message}"
  end

  def pagination_info(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end