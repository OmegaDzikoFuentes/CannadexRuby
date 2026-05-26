class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def up
    create_table :user_preferences do |t|
      t.bigint  :user_id, null: false

      # Notification preferences
      t.boolean :email_notifications,           default: true,  null: false
      t.boolean :push_notifications,            default: true,  null: false
      t.boolean :friend_request_notifications,  default: true,  null: false
      t.boolean :achievement_notifications,     default: true,  null: false
      t.boolean :battle_notifications,          default: true,  null: false

      # Privacy preferences
      t.boolean :profile_public,                default: true,  null: false
      t.boolean :location_sharing_enabled,      default: true,  null: false
      t.boolean :show_location_in_profile,      default: false, null: false
      t.boolean :discoverable_by_username,      default: true,  null: false
      t.boolean :discoverable_by_location,      default: true,  null: false

      t.timestamps
    end

    add_index :user_preferences, :user_id, unique: true
    add_foreign_key :user_preferences, :users

    # Migrate existing data from users table
    execute <<~SQL
      INSERT INTO user_preferences (
        user_id,
        email_notifications,
        push_notifications,
        friend_request_notifications,
        achievement_notifications,
        battle_notifications,
        profile_public,
        location_sharing_enabled,
        show_location_in_profile,
        discoverable_by_username,
        discoverable_by_location,
        created_at,
        updated_at
      )
      SELECT
        id,
        email_notifications,
        push_notifications,
        friend_request_notifications,
        achievement_notifications,
        battle_notifications,
        profile_public,
        location_sharing_enabled,
        show_location_in_profile,
        discoverable_by_username,
        discoverable_by_location,
        NOW(),
        NOW()
      FROM users
    SQL

    # Drop migrated columns from users
    remove_column :users, :email_notifications
    remove_column :users, :push_notifications
    remove_column :users, :friend_request_notifications
    remove_column :users, :achievement_notifications
    remove_column :users, :battle_notifications
    remove_column :users, :profile_public
    remove_column :users, :location_sharing_enabled
    remove_column :users, :show_location_in_profile
    remove_column :users, :discoverable_by_username
    remove_column :users, :discoverable_by_location
  end

  def down
    # Restore columns to users
    add_column :users, :email_notifications,          :boolean, default: true,  null: false
    add_column :users, :push_notifications,           :boolean, default: true,  null: false
    add_column :users, :friend_request_notifications, :boolean, default: true,  null: false
    add_column :users, :achievement_notifications,    :boolean, default: true,  null: false
    add_column :users, :battle_notifications,         :boolean, default: true,  null: false
    add_column :users, :profile_public,               :boolean, default: true,  null: false
    add_column :users, :location_sharing_enabled,     :boolean, default: true,  null: false
    add_column :users, :show_location_in_profile,     :boolean, default: false, null: false
    add_column :users, :discoverable_by_username,     :boolean, default: true,  null: false
    add_column :users, :discoverable_by_location,     :boolean, default: true,  null: false

    execute <<~SQL
      UPDATE users u
      SET
        email_notifications          = up.email_notifications,
        push_notifications           = up.push_notifications,
        friend_request_notifications = up.friend_request_notifications,
        achievement_notifications    = up.achievement_notifications,
        battle_notifications         = up.battle_notifications,
        profile_public               = up.profile_public,
        location_sharing_enabled     = up.location_sharing_enabled,
        show_location_in_profile     = up.show_location_in_profile,
        discoverable_by_username     = up.discoverable_by_username,
        discoverable_by_location     = up.discoverable_by_location
      FROM user_preferences up
      WHERE u.id = up.user_id
    SQL

    drop_table :user_preferences
  end
end
