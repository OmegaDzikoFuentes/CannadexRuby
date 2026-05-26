class CreateUserLocations < ActiveRecord::Migration[8.0]
  def up
    create_table :user_locations do |t|
      t.bigint     :user_id, null: false
      t.geography  :coordinates, limit: { srid: 4326, type: 'st_point', geographic: true }
      t.string     :city,    limit: 100
      t.string     :state,   limit: 50
      t.string     :country, limit: 50
      t.datetime   :located_at  # when location was last updated
      t.timestamps
    end

    add_index :user_locations, :user_id, unique: true
    add_index :user_locations, :coordinates, using: :gist,
              name: "index_user_locations_on_coordinates"
    add_foreign_key :user_locations, :users

    # Migrate data
    execute <<~SQL
      INSERT INTO user_locations (user_id, coordinates, city, state, country, located_at, created_at, updated_at)
      SELECT id, location, city, state, country, updated_at, NOW(), NOW()
      FROM users
    SQL

    # Drop migrated columns from users
    remove_column :users, :location
    remove_column :users, :city
    remove_column :users, :state
    remove_column :users, :country

    remove_index :users, name: "index_users_on_location", if_exists: true
    remove_index :users, name: "index_users_on_discoverable_by_location", if_exists: true
  end

  def down
    add_column :users, :city,    :string, limit: 100
    add_column :users, :state,   :string, limit: 50
    add_column :users, :country, :string, limit: 50
    add_column :users, :location, :geography,
               limit: { srid: 4326, type: 'st_point', geographic: true }

    execute <<~SQL
      UPDATE users u
      SET
        location = ul.coordinates,
        city     = ul.city,
        state    = ul.state,
        country  = ul.country
      FROM user_locations ul
      WHERE u.id = ul.user_id
    SQL

    add_index :users, :location, using: :gist, name: "index_users_on_location"

    drop_table :user_locations
  end
end