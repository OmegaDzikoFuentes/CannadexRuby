class CreateStrains < ActiveRecord::Migration[8.0]
  def change
    create_table :strains do |t|
      t.string :name, limit: 100, null: false
      t.text :description
      t.string :image_url, limit: 255
      t.references :category, null: false, foreign_key: true
      
      # Strain characteristics
      t.string :genetics
      t.decimal :thc_percentage, precision: 5, scale: 2
      t.decimal :cbd_percentage, precision: 5, scale: 2
      t.text :effects, array: true, default: []
      t.text :flavors, array: true, default: []
      t.text :medical_uses, array: true, default: []
      
      # Community data (calculated from encounters)
      t.integer :encounters_count, default: 0, null: false
      t.decimal :average_taste_rating, precision: 3, scale: 2, default: 0.0
      t.decimal :average_smell_rating, precision: 3, scale: 2, default: 0.0
      t.decimal :average_texture_rating, precision: 3, scale: 2, default: 0.0
      t.decimal :average_overall_rating, precision: 3, scale: 2, default: 0.0
      
      # Administrative
      t.boolean :verified, default: false
      t.string :data_source, default: "user_contributed", null: false
      
      t.timestamps null: false
    end
    
    # Remove this line as it's automatically created by t.references
    # add_index :strains, :category_id
    
    add_index :strains, :name, unique: true
    add_index :strains, :verified
    add_index :strains, :encounters_count
    add_index :strains, :average_overall_rating
    add_index :strains, :data_source
    
    # GIN index for array searches
    add_index :strains, :effects, using: :gin
    add_index :strains, :flavors, using: :gin
  end
end