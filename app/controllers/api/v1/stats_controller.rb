# app/controllers/api/v1/stats_controller.rb
class Api::V1::StatsController < Api::V1::ApplicationController
    def user_stats
      stats = UserStatsService.generate_stats(current_user)
      
      render_success({ stats: stats })
    end
    
    def community_stats
      radius = params[:radius]&.to_i || 35
      stats = CommunityStatsService.generate_stats(current_user, radius)
      
      render_success({ community_stats: stats })
    end
  end