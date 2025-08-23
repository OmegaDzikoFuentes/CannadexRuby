# db/migrate/012_create_strain_suggestions.rb
class CreateStrainSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :strain_suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :suggested_name, limit: 100, null: false
      t.text :description
      t.string :genetics
      t.text :effects, array: true, default: []
      t.text :flavors, array: true, default: []
      t.string :status, default: "pending", null: false
      t.references :reviewed_by_user, null: true, foreign_key: { to_table: :users }
      t.text :admin_notes
      t.datetime :reviewed_at
      
      t.timestamps null: false
    end
    
    add_index :strain_suggestions, :user_id
    add_index :strain_suggestions, :status
    add_index :strain_suggestions, :reviewed_by_user_id
    add_index :strain_suggestions, :created_at
    
    # GIN indexes for array searches
    add_index :strain_suggestions, :effects, using: :gin
    add_index :strain_suggestions, :flavors, using: :gin
  end
end