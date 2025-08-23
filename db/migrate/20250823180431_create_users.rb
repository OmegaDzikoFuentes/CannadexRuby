# db/migrate/002_create_users.rb  
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :first_name, limit: 25, null: false
      t.string :last_name, limit: 25, null: false
      t.string :username, limit: 25, null: false
      t.string :email, limit: 255, null: false
      t.string :phone, limit: 20
      t.string :password_digest, null: false
      t.boolean :admin, default: false, null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.string :api_token
      t.text :bio
      
      # Age verification and compliance
      t.date :date_of_birth, null: false
      t.boolean :age_verified, default: false, null: false
      t.datetime :age_verified_at
      
      # Privacy and preferences
      t.boolean :profile_public, default: true, null: false
      t.boolean :location_sharing_enabled, default: true, null: false
      t.boolean :battle_notifications, default: true, null: false
      
      # Gamification stats
      t.integer :total_encounters, default: 0, null: false
      t.integer :battles_won, default: 0, null: false
      t.integer :battles_lost, default: 0, null: false
      t.integer :level, default: 1, null: false
      t.integer :experience_points, default: 0, null: false
      
      # Location (PostGIS geography point)
      t.geography :location, limit: {srid: 4326, type: "st_point", geographic: true}
      t.string :city, limit: 100
      t.string :state, limit: 50
      t.string :country, limit: 50
      
      t.timestamps null: false
    end
    
    add_index :users, :api_token, unique: true
    add_index :users, :email, unique: true
    add_index :users, :username, unique: true
    add_index :users, :location, using: :gist
    add_index :users, :age_verified
    add_index :users, :profile_public
  end
end
