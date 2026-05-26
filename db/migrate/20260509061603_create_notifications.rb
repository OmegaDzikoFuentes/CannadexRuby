class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.bigint  :user_id, null: false
      t.string  :notification_type, null: false       # e.g. 'battle_request', 'friend_request', 'achievement_unlocked'
      t.string  :notifiable_type                      # polymorphic source (Battle, Friendship, Achievement...)
      t.bigint  :notifiable_id
      t.string  :title, limit: 100, null: false
      t.text    :body
      t.jsonb   :data, default: {}                    # extra context (usernames, scores, etc.)
      t.boolean :read, default: false, null: false
      t.boolean :sent_push, default: false, null: false
      t.boolean :sent_email, default: false, null: false
      t.datetime :read_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :notifications, :user_id
    add_index :notifications, [:user_id, :read], name: "index_notifications_on_user_id_and_read"
    add_index :notifications, [:user_id, :created_at], name: "index_notifications_on_user_id_and_created_at"
    add_index :notifications, [:notifiable_type, :notifiable_id], name: "index_notifications_on_notifiable"
    add_index :notifications, :notification_type
    add_index :notifications, :read
    add_index :notifications, :data, using: :gin

    add_foreign_key :notifications, :users
  end
end