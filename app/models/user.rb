# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  # Active Storage
  has_one_attached :avatar

  # Split associations (new)
  has_one :preference,   class_name: 'UserPreference',  dependent: :destroy
  has_one :stat,         class_name: 'UserStat',         dependent: :destroy
  has_one :user_location, class_name: 'UserLocation',    dependent: :destroy

  # Core associations
  has_many :encounters,        dependent: :destroy
  has_many :strains,           through: :encounters
  has_many :achievements,      dependent: :destroy
  has_many :activities,        dependent: :destroy
  has_many :strain_suggestions, dependent: :destroy
  has_many :notifications,     dependent: :destroy

  # Friendship associations
  has_many :friendships, dependent: :destroy
  has_many :inverse_friendships, class_name: 'Friendship', foreign_key: 'friend_id', dependent: :destroy
  has_many :friends,         -> { where(friendships: { status: 'accepted' }) },
           through: :friendships, source: :friend
  has_many :pending_friends, -> { where(friendships: { status: 'pending' }) },
           through: :friendships, source: :friend

  # Battle associations
  has_many :challenged_battles, class_name: 'Battle', foreign_key: 'challenger_id', dependent: :destroy
  has_many :opponent_battles,   class_name: 'Battle', foreign_key: 'opponent_id',   dependent: :destroy
  has_many :won_battles,        class_name: 'Battle', foreign_key: 'winner_id'

  # Validations
  validates :first_name, :last_name, presence: true, length: { maximum: 25 }
  validates :username, presence: true, length: { maximum: 25 },
            uniqueness: { case_sensitive: false }
  validates :email, presence: true, length: { maximum: 255 },
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :date_of_birth, presence: true
  validate  :must_be_21_or_older

  # Scopes
  scope :verified,        -> { where(age_verified: true) }
  scope :public_profiles, -> { joins(:preference).where(user_preferences: { profile_public: true }) }
  scope :near_location, ->(lat, lng, radius_miles = 35) {
    joins(:user_location).where(
      "ST_DWithin(user_locations.coordinates, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
      lng, lat, radius_miles * 1609.34
    )
  }

  # Callbacks
  before_create :generate_api_token
  after_create  :create_default_achievements
  after_create  :create_associated_records

  # ---------------------------------------------------------------------------
  # Delegations to UserPreference
  # ---------------------------------------------------------------------------
  delegate :email_notifications, :email_notifications=,
           :push_notifications, :push_notifications=,
           :friend_request_notifications, :friend_request_notifications=,
           :achievement_notifications, :achievement_notifications=,
           :battle_notifications, :battle_notifications=,
           :profile_public, :profile_public=,
           :location_sharing_enabled, :location_sharing_enabled=,
           :show_location_in_profile, :show_location_in_profile=,
           :discoverable_by_username, :discoverable_by_username=,
           :discoverable_by_location, :discoverable_by_location=,
           to: :preference, allow_nil: true, prefix: false

  # ---------------------------------------------------------------------------
  # Delegations to UserStat
  # ---------------------------------------------------------------------------
  delegate :total_encounters, :total_encounters=,
           :battles_won, :battles_won=,
           :battles_lost, :battles_lost=,
           :level, :level=,
           :experience_points, :experience_points=,
           to: :stat, allow_nil: true, prefix: false

  # ---------------------------------------------------------------------------
  # Delegations to UserLocation
  # ---------------------------------------------------------------------------
  delegate :coordinates, :coordinates=,
           :city, :city=,
           :state, :state=,
           :country, :country=,
           to: :user_location, allow_nil: true, prefix: false

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

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
    total = (battles_won || 0) + (battles_lost || 0)
    return 0.0 if total.zero?
    ((battles_won || 0).to_f / total) * 100
  end

  def level_up_xp_required
    (stat&.level || 1) * 100
  end

  def check_level_up!
    return unless stat
    while stat.experience_points >= level_up_xp_required
      stat.increment!(:level)
    end
  end

  # Convenience: increment a stat column safely
  def increment_stat!(column, by = 1)
    stat&.increment!(column, by)
  end

  # Award XP and check for level up in one call
  def award_xp!(amount)
    return unless stat
    stat.increment!(:experience_points, amount)
    check_level_up!
  end

  # Unread notification count
  def unread_notifications_count
    notifications.unread.count
  end

  private

  def must_be_21_or_older
    return unless date_of_birth
    errors.add(:date_of_birth, "must be 21 or older") if age < 21
  end

  def generate_api_token
    self.api_token = SecureRandom.hex(20)
  end

  # Create UserPreference, UserStat, and UserLocation rows after user creation
  def create_associated_records
    create_preference!  unless preference
    create_stat!        unless stat
    create_user_location! unless user_location
  end

  def create_default_achievements
    Achievement::TYPES.each do |type, config|
      achievements.create!(
        achievement_type: type,
        title:            config[:title],
        description:      config[:description],
        goal:             config[:goal],
        xp_reward:        config[:xp_reward]
      )
    end
  end
end