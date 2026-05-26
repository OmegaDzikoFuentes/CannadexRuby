# app/models/achievement_progress.rb
class AchievementProgress < ApplicationRecord
  belongs_to :achievement
  belongs_to :user  # direct association — no join through achievement needed

  validates :progress_amount, presence: true, numericality: { greater_than: 0 }

  scope :recent,   -> { order(created_at: :desc) }
  # No longer needs a join — user_id is directly on this table
  scope :for_user, ->(user) { where(user: user) }

  def achievement_type
    achievement.achievement_type
  end

  def contributed_to_unlock?
    achievement.reload
    old_progress = achievement.progress - progress_amount
    old_progress < achievement.goal && achievement.progress >= achievement.goal
  end

  private

  def log_progress
    Rails.logger.info(
      "Achievement progress: User #{user_id} made progress on #{achievement_type} (+#{progress_amount})"
    )
  end
end