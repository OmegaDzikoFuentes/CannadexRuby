# app/models/achievement_progress.rb
class AchievementProgress < ApplicationRecord
    belongs_to :achievement
    
    validates :progress_amount, presence: true, numericality: { greater_than: 0 }
    
    scope :recent, -> { order(created_at: :desc) }
    scope :for_user, ->(user) { joins(:achievement).where(achievements: { user: user }) }
    
    after_create :update_achievement_progress
    
    def user
      achievement.user
    end
    
    def achievement_type
      achievement.achievement_type
    end
    
    def contributed_to_unlock?
      # Check if this progress entry was the one that caused the unlock
      achievement.reload
      old_progress = achievement.progress - progress_amount
      old_progress < achievement.goal && achievement.progress >= achievement.goal
    end
    
    private
    
    def update_achievement_progress
      # This is handled by the Achievement#add_progress! method
      # but we could add additional logic here if needed
      
      # Log progress for analytics
      Rails.logger.info "Achievement progress: User #{user.id} made progress on #{achievement_type} (+#{progress_amount})"
    end
  end