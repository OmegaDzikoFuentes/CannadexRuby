# db/migrate/010_create_achievements.rb
class CreateAchievements < ActiveRecord::Migration[8.0]
  def change
    create_table :achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :achievement_type, null: false
      t.string :title, limit: 100, null: false
      t.text :description
      t.integer :progress, default: 0, null: false
      t.integer :goal, default: 10, null: false
      t.string :reward_description
      t.integer :xp_reward, default: 0, null: false
      t.string :badge_image_url
      t.boolean :is_unlocked, default: false, null: false
      t.boolean :is_claimed, default: false, null: false
      t.datetime :unlocked_at
      t.datetime :claimed_at
      
      t.timestamps null: false
    end
    
    # Keep the composite index (this is not automatically created)
    add_index :achievements, [:user_id, :achievement_type], unique: true
    
    # Remove this duplicate index (it's automatically created by t.references)
    # add_index :achievements, :user_id
    
    add_index :achievements, :is_unlocked
    add_index :achievements, :achievement_type
  end
end