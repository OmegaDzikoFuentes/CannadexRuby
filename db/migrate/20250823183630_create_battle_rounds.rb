# db/migrate/008_create_battle_rounds.rb
class CreateBattleRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :battle_rounds do |t|
      t.references :battle, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.references :challenger_strain, null: false, foreign_key: { to_table: :strains }
      t.references :opponent_strain, null: false, foreign_key: { to_table: :strains }
      t.references :winner_strain, null: true, foreign_key: { to_table: :strains }
      t.text :round_results # JSON with detailed scoring
      
      t.timestamps null: false
    end
    

    add_index :battle_rounds, [:battle_id, :round_number], unique: true
    
    # Constraint: round_number must be 1, 2, or 3
    add_check_constraint :battle_rounds, "round_number BETWEEN 1 AND 3", name: "valid_round_number"
  end
end