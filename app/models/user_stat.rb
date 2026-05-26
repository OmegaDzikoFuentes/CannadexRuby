# app/models/user_stat.rb
class UserStat < ApplicationRecord
    belongs_to :user
  
    validates :user_id, presence: true, uniqueness: true
    validates :total_encounters, :battles_won, :battles_lost, :level, :experience_points,
              numericality: { greater_than_or_equal_to: 0 }
  
    scope :leaderboard, -> { order(battles_won: :desc, level: :desc) }
    scope :top_explorers, -> { order(total_encounters: :desc) }
  
    def win_rate
      total = battles_won + battles_lost
      return 0.0 if total.zero?
      (battles_won.to_f / total) * 100
    end
  
    def xp_to_next_level
      (level * 100) - experience_points
    end
  
    def level_progress_percentage
      xp_in_level = experience_points % (level * 100)
      (xp_in_level.to_f / (level * 100) * 100).round(1)
    end
  end