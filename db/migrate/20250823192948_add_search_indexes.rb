# db/migrate/017_add_search_indexes.rb
class AddSearchIndexes < ActiveRecord::Migration[8.0]
  def change
    # Text search indexes for better search performance

    add_index :strains, :description, opclass: :gin_trgm_ops, using: :gin

    
    # Composite indexes for common queries
    add_index :encounters, [:user_id, :encountered_at]
    add_index :encounters, [:strain_id, :encountered_at]
    add_index :encounters, [:public, :encountered_at]
    add_index :strains, [:category_id, :average_overall_rating]
    add_index :strains, [:verified, :encounters_count]
    
    # Battle-related composite indexes
    add_index :battles, [:challenger_id, :status]
    add_index :battles, [:opponent_id, :status]
    add_index :battles, [:status, :created_at]
  end
end