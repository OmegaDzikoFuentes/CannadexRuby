class HealthController < ApplicationController
    skip_before_action :authenticate_user!
    
    def check
      head :ok  # Or render plain: 'OK' for a simple text response
    end
  end