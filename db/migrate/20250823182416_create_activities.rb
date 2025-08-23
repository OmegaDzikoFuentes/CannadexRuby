
# db/migrate/013_create_activities.rb
class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.string :trackable_type, null: false
      t.bigint :trackable_id, null: false
      t.text :data # JSON for additional context
      t.boolean :public, default: true, null: false
      
      t.timestamps null: false
    end
    
    add_index :activities, :user_id
    add_index :activities, [:trackable_type, :trackable_id]
    add_index :activities, :activity_type
    add_index :activities, :created_at
    add_index :activities, :public
    
    # Composite index for user feeds
    add_index :activities, [:user_id, :created_at]
    add_index :activities, [:public, :created_at]
  end
end
