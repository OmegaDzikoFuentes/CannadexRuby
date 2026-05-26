# app/models/user_preference.rb
class UserPreference < ApplicationRecord
    belongs_to :user
  
    validates :user_id, presence: true, uniqueness: true
  
    # Notification helpers
    def any_notifications_enabled?
      email_notifications? || push_notifications?
    end
  
    def notify_for?(type)
      case type.to_sym
      when :friend_request  then friend_request_notifications?
      when :achievement     then achievement_notifications?
      when :battle          then battle_notifications?
      when :email           then email_notifications?
      when :push            then push_notifications?
      else true
      end
    end
  end