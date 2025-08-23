
# app/models/achievement.rb
class Achievement < ApplicationRecord
    belongs_to :user
    has_many :achievement_progresses, dependent: :destroy
    
    validates :achievement_type, presence: true, uniqueness: { scope: :user_id }
    validates :progress, :goal, :xp_reward, numericality: { greater_than_or_equal_to: 0 }
    
    scope :unlocked, -> { where(is_unlocked: true) }
    scope :locked, -> { where(is_unlocked: false) }
    scope :claimed, -> { where(is_claimed: true) }
    scope :unclaimed, -> { where(is_unlocked: true, is_claimed: false) }
    
    # Achievement type configurations
    TYPES = {
      'first_encounter' => {
        title: 'First Bud',
        description: 'Upload your first bud to the Cannadex',
        goal: 1,
        xp_reward: 25
      },
      'strain_collector' => {
        title: 'Strain Collector',
        description: 'Catalog 10 different strains',
        goal: 10,
        xp_reward: 100
      },
      'battle_rookie' => {
        title: 'Battle Rookie', 
        description: 'Win your first battle',
        goal: 1,
        xp_reward: 50
      },
      'social_butterfly' => {
        title: 'Social Butterfly',
        description: 'Add 5 sesh pals',
        goal: 5,
        xp_reward: 75
      },
      'explorer' => {
        title: 'Explorer',
        description: 'Log encounters in 5 different cities',
        goal: 5,
        xp_reward: 150
      },
      'connoisseur' => {
        title: 'Connoisseur',
        description: 'Rate 50 different strains',
        goal: 50,
        xp_reward: 200
      }
    }.freeze
    
    def progress_percentage
      return 100.0 if is_unlocked?
      return 0.0 if goal.zero?
      (progress.to_f / goal * 100).round(1)
    end
    
    def add_progress!(amount = 1)
      return if is_unlocked?
      
      self.progress = [progress + amount, goal].min
      
      if progress >= goal && !is_unlocked?
        unlock!
      else
        save!
      end
      
      achievement_progresses.create!(progress_amount: amount)
    end
    
    def unlock!
      update!(
        is_unlocked: true,
        unlocked_at: Time.current
      )
      
      # Award XP to user
      user.update_column(:experience_points, user.experience_points + xp_reward)
      user.check_level_up!
      
      # Create activity
      user.activities.create!(
        activity_type: 'achievement_unlocked',
        trackable: self,
        data: {
          achievement_title: title,
          xp_earned: xp_reward
        }
      )
    end
    
    def claim!
      return unless is_unlocked? && !is_claimed?
      
      update!(
        is_claimed: true,
        claimed_at: Time.current
      )
    end
  end
  