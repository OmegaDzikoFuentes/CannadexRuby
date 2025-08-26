# db/migrate/003_create_categories.rb
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, limit: 25, null: false
      t.string :description, limit: 200
      t.string :image_url, limit: 255
      t.string :category_type, default: "strain_type", null: false
      t.boolean :active, default: true, null: false
      t.integer :strains_count, default: 0, null: false
      
      t.timestamps null: false
    end
    
    add_index :categories, :category_type
    add_index :categories, :active
    add_index :categories, :name
  end
end