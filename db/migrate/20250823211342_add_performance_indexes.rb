# Additional migration for better indexing
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # For leaderboards and user stats
    add_index :users, [:level, :experience_points]
    add_index :users, :battles_won
    
    # For strain recommendations
    add_index :strains, [:category_id, :verified, :average_overall_rating]
    
    # For battle matchmaking
    add_index :friendships, [:user_id, :status, :created_at]
  end
end