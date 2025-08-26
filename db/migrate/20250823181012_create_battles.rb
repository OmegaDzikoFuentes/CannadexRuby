# db/migrate/007_create_battles.rb
class CreateBattles < ActiveRecord::Migration[8.0]
  def change
    create_table :battles do |t|
      t.references :challenger, null: false, foreign_key: { to_table: :users }
      t.references :opponent, null: false, foreign_key: { to_table: :users }
      t.string :status, default: "pending", null: false
      t.references :winner, null: true, foreign_key: { to_table: :users }
      t.integer :challenger_score, default: 0, null: false
      t.integer :opponent_score, default: 0, null: false
      t.text :battle_results # JSON storing detailed results
      t.datetime :battled_at
      t.datetime :expires_at, null: false, default: -> { 'CURRENT_TIMESTAMP + INTERVAL \'24 hours\'' }
      
      t.timestamps null: false
    end
    
    
    add_index :battles, :status
    add_index :battles, :battled_at
    add_index :battles, :expires_at
    
    # Ensure challenger and opponent are different
    add_check_constraint :battles, "challenger_id != opponent_id", name: "prevent_self_battle"
  end
end