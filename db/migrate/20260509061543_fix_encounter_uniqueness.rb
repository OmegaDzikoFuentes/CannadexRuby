class FixEncounterUniqueness < ActiveRecord::Migration[8.0]
  def up
    # Drop the unique constraint that prevents multiple encounters per strain
    remove_index :encounters, name: "unique_user_strain_encounter"

    # Replace with a non-unique composite index for query performance
    add_index :encounters, [:user_id, :strain_id], name: "index_encounters_on_user_id_and_strain_id"

    # Add an encounter number per user/strain pair for ordering
    add_column :encounters, :encounter_number, :integer, default: 1, null: false

    # Backfill encounter_number for any existing duplicate-free data
    execute <<~SQL
      UPDATE encounters e
      SET encounter_number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, strain_id ORDER BY encountered_at) AS rn
        FROM encounters
      ) sub
      WHERE e.id = sub.id
    SQL

    add_index :encounters, [:user_id, :strain_id, :encounter_number],
              name: "index_encounters_on_user_strain_number"
  end

  def down
    remove_column :encounters, :encounter_number
    remove_index :encounters, name: "index_encounters_on_user_id_and_strain_id"
    remove_index :encounters, name: "index_encounters_on_user_strain_number"

    # Restore unique constraint — will fail if duplicates exist
    add_index :encounters, [:user_id, :strain_id],
              unique: true,
              name: "unique_user_strain_encounter"
  end
end
