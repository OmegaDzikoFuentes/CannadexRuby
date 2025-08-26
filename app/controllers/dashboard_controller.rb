class DashboardController < ApplicationController
    before_action :authenticate_user!
  
    # GET /dashboard
    def index
      @dashboard_data = {
        user: current_user.full_name,
        level: current_user.level,
        xp: current_user.experience_points,
        recent_encounters: current_user.encounters.recent.limit(5).map { |e| { strain: e.strain.name, rating: e.overall_rating } },
        pending_battles: current_user.pending_battles.count,
        unlocked_achievements: current_user.achievements.unlocked.count,
        unread_notifications: current_user.notifications.unread.count
      }
  
      render 'dashboard/index', locals: @dashboard_data
    end
  end