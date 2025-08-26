# db/migrate/005_create_encounters.rb
class CreateEncounters < ActiveRecord::Migration[8.0]
  def change
    create_table :encounters do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strain, null: false, foreign_key: true
      t.datetime :encountered_at, null: false
      
      # Ratings (0-10 scale)
      t.integer :taste_rating, default: 0, null: false
      t.integer :smell_rating, default: 0, null: false
      t.integer :texture_rating, default: 0, null: false
      t.integer :overall_rating, default: 0, null: false
      t.integer :potency_rating, default: 0, null: false
      
      # Text fields
      t.text :description
      t.text :experience
      t.text :effects_experienced, array: true, default: []
      
      # Location data (PostGIS geography point)
      t.geography :location, limit: {srid: 4326, type: "st_point", geographic: true}
      t.string :location_name, limit: 100
      
      # Purchase/source info (optional)
      t.string :source_type # "dispensary", "friend", "homegrown", "other"
      t.string :source_name, limit: 100
      t.decimal :price_paid, precision: 8, scale: 2
      t.string :amount_purchased, limit: 50
      
      # Privacy and sharing
      t.boolean :public, default: true, null: false
      t.boolean :friends_only, default: false, null: false
      
      # Digital card generation
      t.string :card_image_url
      t.boolean :card_generated, default: false, null: false
      
      t.timestamps null: false
    end
    
    # REMOVED: add_index :encounters, :strain_id (duplicate of auto-created index)
    # REMOVED: add_index :encounters, :user_id (duplicate of auto-created index)
    
    add_index :encounters, [:user_id, :strain_id], unique: true, name: 'unique_user_strain_encounter'
    add_index :encounters, :location, using: :gist
    add_index :encounters, :encountered_at
    add_index :encounters, :public
    add_index :encounters, :card_generated
    add_index :encounters, :effects_experienced, using: :gin
  end
end