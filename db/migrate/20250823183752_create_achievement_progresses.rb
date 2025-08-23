# db/migrate/011_create_achievement_progresses.rb
class CreateAchievementProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :achievement_progresses do |t|
      t.references :achievement, null: false, foreign_key: true
      t.integer :progress_amount, default: 1, null: false
      
      t.timestamps null: false
    end
    
    add_index :achievement_progresses, :achievement_id
    add_index :achievement_progresses, :created_at
  end
end
