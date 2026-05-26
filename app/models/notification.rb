# app/models/notification.rb
class Notification < ApplicationRecord
    belongs_to :user
    belongs_to :notifiable, polymorphic: true, optional: true
  
    validates :notification_type, presence: true
    validates :title, presence: true, length: { maximum: 100 }
  
    TYPES = %w[
      battle_request
      battle_accepted
      battle_completed
      friend_request
      friend_accepted
      achievement_unlocked
      encounter_liked
      system
    ].freeze
  
    validates :notification_type, inclusion: { in: TYPES }
  
    scope :unread,   -> { where(read: false) }
    scope :read,     -> { where(read: true) }
    scope :recent,   -> { order(created_at: :desc) }
    scope :for_type, ->(type) { where(notification_type: type) }
  
    def mark_read!
      update!(read: true, read_at: Time.current) unless read?
    end
  
    def self.mark_all_read_for!(user)
      user.notifications.unread.update_all(read: true, read_at: Time.current)
    end
  
    # Factory method — respects user preferences before creating
    def self.deliver_to(user, type:, title:, body: nil, notifiable: nil, data: {})
      return unless user.preference&.notify_for?(type)
  
      create!(
        user:              user,
        notification_type: type,
        title:             title,
        body:              body,
        notifiable:        notifiable,
        data:              data
      )
    end
  end