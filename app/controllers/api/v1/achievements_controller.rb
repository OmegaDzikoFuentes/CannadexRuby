# app/controllers/api/v1/achievements_controller.rb
class Api::V1::AchievementsController < Api::V1::ApplicationController
    before_action :find_achievement, only: [:show, :claim]
    
    def index
      achievements = current_user.achievements.order(:is_unlocked, :created_at)
      
      unlocked = achievements.unlocked
      locked = achievements.locked
      
      render_success({
        achievements: achievements.map { |a| achievement_data(a) },
        summary: {
          total: achievements.count,
          unlocked: unlocked.count,
          locked: locked.count,
          unclaimed: achievements.unclaimed.count,
          total_xp_earned: unlocked.sum(:xp_reward),
          total_xp_available: achievements.sum(:xp_reward)
        }
      })
    end
    
    def show
      render_success({ achievement: detailed_achievement_data(@achievement) })
    end
    
    def unlocked
      achievements = current_user.achievements.unlocked.order(unlocked_at: :desc)
      
      render_success({
        achievements: achievements.map { |a| achievement_data(a) }
      })
    end
    
    def available
      achievements = current_user.achievements.locked.order(:goal)
      
      render_success({
        achievements: achievements.map { |a| achievement_data(a) }
      })
    end
    
    def claim
      return render_error('Achievement not unlocked') unless @achievement.is_unlocked?
      return render_error('Achievement already claimed') if @achievement.is_claimed?
      
      @achievement.claim!
      
      render_success(
        { achievement: achievement_data(@achievement) },
        'Achievement claimed!'
      )
    end
    
    private
    
    def find_achievement
      @achievement = current_user.achievements.find(params[:id])
    end
    
    def achievement_data(achievement)
      {
        id: achievement.id,
        achievement_type: achievement.achievement_type,
        title: achievement.title,
        description: achievement.description,
        progress: achievement.progress,
        goal: achievement.goal,
        progress_percentage: achievement.progress_percentage,
        xp_reward: achievement.xp_reward,
        reward_description: achievement.reward_description,
        badge_image_url: achievement.badge_image_url,
        is_unlocked: achievement.is_unlocked?,
        is_claimed: achievement.is_claimed?,
        unlocked_at: achievement.unlocked_at,
        claimed_at: achievement.claimed_at,
        created_at: achievement.created_at
      }
    end
    
    def detailed_achievement_data(achievement)
      data = achievement_data(achievement)
      
      # Add progress history
      progress_history = achievement.achievement_progresses
                                   .order(created_at: :desc)
                                   .limit(10)
                                   .map do |progress|
        {
          progress_amount: progress.progress_amount,
          created_at: progress.created_at
        }
      end
      
      data[:progress_history] = progress_history
      data
    end
  end