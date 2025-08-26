# db/migrate/009_create_battle_strains.rb
class CreateBattleStrains < ActiveRecord::Migration[8.0]
  def change
    create_table :battle_strains do |t|
      t.references :battle, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :strain, null: false, foreign_key: true
      t.integer :position, null: false # 1, 2, or 3 for ordering
      
      t.timestamps null: false
    end
    

    add_index :battle_strains, [:battle_id, :user_id, :position], unique: true
    
    # Constraint: position must be 1, 2, or 3
    add_check_constraint :battle_strains, "position BETWEEN 1 AND 3", name: "valid_position"
  end
end
