# db/migrate/006_create_friendships.rb
class CreateFriendships < ActiveRecord::Migration[8.0]
  def change
    create_table :friendships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :friend, null: false, foreign_key: { to_table: :users }
      t.string :status, default: "pending", null: false
      t.datetime :requested_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :accepted_at
      
      t.timestamps null: false
    end
    
    add_index :friendships, [:user_id, :friend_id], unique: true
    add_index :friendships, :status
    add_index :friendships, :requested_at
    
    # Ensure users can't friend themselves
    add_check_constraint :friendships, "user_id != friend_id", name: "prevent_self_friendship"
  end
end