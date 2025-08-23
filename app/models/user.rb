# app/models/user.rb
class User < ApplicationRecord
    has_secure_password
    
    # Active Storage associations
    has_one_attached :avatar
    
    # Core associations
    has_many :encounters, dependent: :destroy
    has_many :strains, through: :encounters
    has_many :achievements, dependent: :destroy
    has_many :activities, dependent: :destroy
    has_many :strain_suggestions, dependent: :destroy
    
    # Friendship associations
    has_many :friendships, dependent: :destroy
    has_many :inverse_friendships, class_name: 'Friendship', foreign_key: 'friend_id', dependent: :destroy
    has_many :friends, -> { where(friendships: { status: 'accepted' }) }, 
             through: :friendships, source: :friend
    has_many :pending_friends, -> { where(friendships: { status: 'pending' }) },
             through: :friendships, source: :friend
    
    # Battle associations
    has_many :challenged_battles, class_name: 'Battle', foreign_key: 'challenger_id', dependent: :destroy
    has_many :opponent_battles, class_name: 'Battle', foreign_key: 'opponent_id', dependent: :destroy
    has_many :won_battles, class_name: 'Battle', foreign_key: 'winner_id'
    
    # Validations
    validates :first_name, :last_name, presence: true, length: { maximum: 25 }
    validates :username, presence: true, length: { maximum: 25 }, 
              uniqueness: { case_sensitive: false }
    validates :email, presence: true, length: { maximum: 255 },
              uniqueness: { case_sensitive: false },
              format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :date_of_birth, presence: true
    validate :must_be_21_or_older
    
    # Scopes
    scope :verified, -> { where(age_verified: true) }
    scope :public_profiles, -> { where(profile_public: true) }
    scope :near_location, ->(lat, lng, radius_miles = 35) {
      where(
        "ST_DWithin(location, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
        lng, lat, radius_miles * 1609.34 # Convert miles to meters
      )
    }
    
    # Callbacks
    before_create :generate_api_token
    after_create :create_default_achievements
    
    def full_name
      "#{first_name} #{last_name}"
    end
    
    def age
      return nil unless date_of_birth
      ((Date.current - date_of_birth) / 365.25).floor
    end
    
    def age_verified?
      age_verified && age >= 21
    end
    
    def battles
      Battle.where("challenger_id = ? OR opponent_id = ?", id, id)
    end
    
    def win_rate
      return 0.0 if battles_won.zero? && battles_lost.zero?
      (battles_won.to_f / (battles_won + battles_lost)) * 100
    end
    
    def level_up_xp_required
      level * 100 # Simple progression: 100, 200, 300, etc.
    end
    
    def check_level_up!
      while experience_points >= level_up_xp_required
        increment!(:level)
        # Could trigger achievement here
      end
    end
    
    private
    
    def must_be_21_or_older
      return unless date_of_birth
      errors.add(:date_of_birth, "must be 21 or older") if age < 21
    end
    
    def generate_api_token
      self.api_token = SecureRandom.hex(20)
    end
    
    def create_default_achievements
      Achievement::TYPES.each do |type, config|
        achievements.create!(
          achievement_type: type,
          title: config[:title],
          description: config[:description],
          goal: config[:goal],
          xp_reward: config[:xp_reward]
        )
      end
    end
  end