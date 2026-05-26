class CreateUserStats < ActiveRecord::Migration[8.0]
  def up
    create_table :user_stats do |t|
      t.bigint  :user_id, null: false
      t.integer :total_encounters, default: 0, null: false
      t.integer :battles_won,      default: 0, null: false
      t.integer :battles_lost,     default: 0, null: false
      t.integer :level,            default: 1, null: false
      t.integer :experience_points, default: 0, null: false
      t.timestamps
    end

    add_index :user_stats, :user_id, unique: true
    add_index :user_stats, [:level, :experience_points],
              name: "index_user_stats_on_level_and_xp"
    add_index :user_stats, :battles_won
    add_foreign_key :user_stats, :users

    # Migrate data
    execute <<~SQL
      INSERT INTO user_stats (
        user_id, total_encounters, battles_won, battles_lost,
        level, experience_points, created_at, updated_at
      )
      SELECT
        id, total_encounters, battles_won, battles_lost,
        level, experience_points, NOW(), NOW()
      FROM users
    SQL

    # Drop migrated columns from users
    remove_column :users, :total_encounters
    remove_column :users, :battles_won
    remove_column :users, :battles_lost
    remove_column :users, :level
    remove_column :users, :experience_points

    # Clean up now-redundant indexes on users
    remove_index :users, name: "index_users_on_level_and_experience_points", if_exists: true
    remove_index :users, name: "index_users_on_battles_won", if_exists: true
  end

  def down
    add_column :users, :total_encounters,    :integer, default: 0, null: false
    add_column :users, :battles_won,         :integer, default: 0, null: false
    add_column :users, :battles_lost,        :integer, default: 0, null: false
    add_column :users, :level,               :integer, default: 1, null: false
    add_column :users, :experience_points,   :integer, default: 0, null: false

    execute <<~SQL
      UPDATE users u
      SET
        total_encounters  = us.total_encounters,
        battles_won       = us.battles_won,
        battles_lost      = us.battles_lost,
        level             = us.level,
        experience_points = us.experience_points
      FROM user_stats us
      WHERE u.id = us.user_id
    SQL

    add_index :users, [:level, :experience_points],
              name: "index_users_on_level_and_experience_points"
    add_index :users, :battles_won

    drop_table :user_stats
  end
end