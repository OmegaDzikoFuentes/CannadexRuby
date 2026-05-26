class FixAbilitiesAndAchievementProgresses < ActiveRecord::Migration[8.0]
  def up
    # CanCan's Ability is a plain Ruby object (not AR), so the abilities table
    # is never actually used by CanCan itself. Repurpose it as a custom
    # role/permission store in case you want DB-backed permissions later,
    # or simply drop it. We'll repurpose it as a roles table.
    rename_table :abilities, :roles

    add_column :roles, :name,          :string, limit: 50, null: false, default: ''
    add_column :roles, :subject_class, :string, limit: 100  # e.g. 'Strain', 'User', ':all'
    add_column :roles, :action,        :string, limit: 50   # e.g. 'manage', 'read', 'create'
    add_column :roles, :description,   :text

    add_index :roles, :name, unique: true

    # Join table: assign roles to users
    create_table :user_roles do |t|
      t.bigint :user_id, null: false
      t.bigint :role_id, null: false
      t.timestamps
    end

    add_index :user_roles, [:user_id, :role_id], unique: true
    add_index :user_roles, :user_id
    add_index :user_roles, :role_id
    add_foreign_key :user_roles, :users
    add_foreign_key :user_roles, :roles

    # Add user_id to achievement_progresses to avoid always joining through achievements
    add_column :achievement_progresses, :user_id, :bigint, null: true

    execute <<~SQL
      UPDATE achievement_progresses ap
      SET user_id = a.user_id
      FROM achievements a
      WHERE ap.achievement_id = a.id
    SQL

    change_column_null :achievement_progresses, :user_id, false

    add_index :achievement_progresses, :user_id,
              name: "index_achievement_progresses_on_user_id"
    add_index :achievement_progresses, [:user_id, :created_at],
              name: "index_achievement_progresses_on_user_id_and_created_at"
    add_foreign_key :achievement_progresses, :users
  end

  def down
    remove_foreign_key :achievement_progresses, :users
    remove_index :achievement_progresses, name: "index_achievement_progresses_on_user_id"
    remove_index :achievement_progresses, name: "index_achievement_progresses_on_user_id_and_created_at"
    remove_column :achievement_progresses, :user_id

    drop_table :user_roles
    remove_column :roles, :name
    remove_column :roles, :subject_class
    remove_column :roles, :action
    remove_column :roles, :description
    rename_table :roles, :abilities
  end
end