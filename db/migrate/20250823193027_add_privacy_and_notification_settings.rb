# db/migrate/018_add_privacy_and_notification_settings.rb
class AddPrivacyAndNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_notifications, :boolean, default: true, null: false
    add_column :users, :push_notifications, :boolean, default: true, null: false
    add_column :users, :friend_request_notifications, :boolean, default: true, null: false
    add_column :users, :achievement_notifications, :boolean, default: true, null: false
    
    # Privacy settings
    add_column :users, :show_location_in_profile, :boolean, default: false, null: false
    add_column :users, :discoverable_by_username, :boolean, default: true, null: false
    add_column :users, :discoverable_by_location, :boolean, default: true, null: false
    
    add_index :users, :discoverable_by_username
    add_index :users, :discoverable_by_location
  end
end
