class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    # Trigram index on strains.name for fuzzy search
    # (requires pg_trgm which is already enabled)
    execute "CREATE INDEX IF NOT EXISTS index_strains_on_name_trgm ON strains USING gin (name gin_trgm_ops)"

    # Encounters: index on location_name for filtering
    add_index :encounters, :location_name, name: "index_encounters_on_location_name", if_not_exists: true

    # Encounters: source_type is commonly filtered on
    add_index :encounters, :source_type, name: "index_encounters_on_source_type", if_not_exists: true

    # Users: trigram on username for search
    execute "CREATE INDEX IF NOT EXISTS index_users_on_username_trgm ON users USING gin (username gin_trgm_ops)"

    # Achievements: index on claimed state for reward screens
    add_index :achievements, [:user_id, :is_claimed],
              name: "index_achievements_on_user_id_and_is_claimed", if_not_exists: true

    # Notifications: compound index for unread counts (added here for completeness,
    # but also in the create_notifications migration above)
    # Skipped here since create_notifications handles it.

    # Strain suggestions: reviewed_at for admin queues
    add_index :strain_suggestions, :reviewed_at,
              name: "index_strain_suggestions_on_reviewed_at", if_not_exists: true
  end
end