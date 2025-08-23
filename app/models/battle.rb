# app/models/battle.rb
class Battle < ApplicationRecord
    belongs_to :challenger, class_name: 'User'
    belongs_to :opponent, class_name: 'User'  
    belongs_to :winner, class_name: 'User', optional: true
    
    has_many :battle_rounds, dependent: :destroy
    has_many :battle_strains, dependent: :destroy
    has_many :activities, as: :trackable, dependent: :destroy
    
    validates :challenger, :opponent, presence: true
    validates :status, inclusion: { in: %w[pending active completed cancelled] }
    validate :challenger_and_opponent_are_different
    validate :users_are_friends
    
    scope :pending, -> { where(status: 'pending') }
    scope :active, -> { where(status: 'active') }  
    scope :completed, -> { where(status: 'completed') }
    
    before_create :set_expiration
    after_update :create_battle_activity, if: :saved_change_to_status?
    
    def participants
      [challenger, opponent]
    end
    
    def opponent_for(user)
      user == challenger ? opponent : challenger
    end
    
    def strains_for_user(user)
      battle_strains.where(user: user).includes(:strain).order(:position)
    end
    
    def can_be_accepted?
      status == 'pending' && !expired?
    end
    
    def expired?
      expires_at < Time.current
    end
    
    def accept!
      return false unless can_be_accepted?
      
      transaction do
        update!(status: 'active')
        conduct_battle!
      end
    end
    
    def conduct_battle!
      challenger_strains = strains_for_user(challenger).map(&:strain)
      opponent_strains = strains_for_user(opponent).map(&:strain)
      
      challenger_wins = 0
      opponent_wins = 0
      
      3.times do |round|
        c_strain = challenger_strains[round]
        o_strain = opponent_strains[round]
        
        # Calculate round winner based on average ratings
        c_score = c_strain.average_overall_rating
        o_score = o_strain.average_overall_rating
        
        round_winner = c_score > o_score ? challenger : opponent
        if c_score > o_score
          challenger_wins += 1
        else
          opponent_wins += 1
        end
        
        battle_rounds.create!(
          round_number: round + 1,
          challenger_strain: c_strain,
          opponent_strain: o_strain,
          winner_strain: round_winner == challenger ? c_strain : o_strain,
          round_results: {
            challenger_score: c_score,
            opponent_score: o_score,
            winner: round_winner.username
          }
        )
      end
      
      # Determine overall winner (best of 3)
      battle_winner = challenger_wins > opponent_wins ? challenger : opponent
      battle_loser = battle_winner == challenger ? opponent : challenger
      
      update!(
        status: 'completed',
        winner: battle_winner,
        challenger_score: challenger_wins,
        opponent_score: opponent_wins,
        battled_at: Time.current,
        battle_results: {
          rounds: battle_rounds.count,
          winner_rounds: challenger_wins > opponent_wins ? challenger_wins : opponent_wins,
          loser_rounds: challenger_wins > opponent_wins ? opponent_wins : challenger_wins
        }
      )
      
      # Update user stats
      battle_winner.increment!(:battles_won)
      battle_loser.increment!(:battles_lost)
      
      # Award XP
      battle_winner.update_column(:experience_points, battle_winner.experience_points + 50)
      battle_loser.update_column(:experience_points, battle_loser.experience_points + 10)
      
      # Check for level ups and achievements
      [battle_winner, battle_loser].each do |user|
        user.check_level_up!
        CheckAchievementsJob.perform_later(user, 'battle_completed')
      end
    end
    
    private
    
    def challenger_and_opponent_are_different
      errors.add(:opponent, "can't battle yourself") if challenger == opponent
    end
    
    def users_are_friends
      return unless challenger && opponent
      
      friendship = Friendship.find_by(
        user: challenger, 
        friend: opponent, 
        status: 'accepted'
      )
      
      errors.add(:opponent, "must be friends to battle") unless friendship
    end
    
    def set_expiration
      self.expires_at = 24.hours.from_now
    end
    
    def create_battle_activity
      case status
      when 'completed'
        activities.create!(
          user: winner,
          activity_type: 'battle_won',
          data: {
            opponent_username: opponent_for(winner).username,
            score: "#{challenger_score}-#{opponent_score}"
          }
        )
      end
    end
  end