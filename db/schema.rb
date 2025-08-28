# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_28_175623) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"

  create_table "abilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "achievement_progresses", force: :cascade do |t|
    t.bigint "achievement_id", null: false
    t.integer "progress_amount", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_id"], name: "index_achievement_progresses_on_achievement_id"
    t.index ["created_at"], name: "index_achievement_progresses_on_created_at"
  end

  create_table "achievements", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "achievement_type", null: false
    t.string "title", limit: 100, null: false
    t.text "description"
    t.integer "progress", default: 0, null: false
    t.integer "goal", default: 10, null: false
    t.string "reward_description"
    t.integer "xp_reward", default: 0, null: false
    t.string "badge_image_url"
    t.boolean "is_unlocked", default: false, null: false
    t.boolean "is_claimed", default: false, null: false
    t.datetime "unlocked_at"
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achievement_type"], name: "index_achievements_on_achievement_type"
    t.index ["is_unlocked"], name: "index_achievements_on_is_unlocked"
    t.index ["user_id", "achievement_type"], name: "index_achievements_on_user_id_and_achievement_type", unique: true
    t.index ["user_id"], name: "index_achievements_on_user_id"
  end

  create_table "activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "activity_type", null: false
    t.string "trackable_type", null: false
    t.bigint "trackable_id", null: false
    t.text "data"
    t.boolean "public", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_activities_on_activity_type"
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["public", "created_at"], name: "index_activities_on_public_and_created_at"
    t.index ["public"], name: "index_activities_on_public"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable_type_and_trackable_id"
    t.index ["user_id", "created_at"], name: "index_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "app_infos", force: :cascade do |t|
    t.string "name", limit: 100
    t.string "tagline", limit: 200
    t.text "about_text"
    t.string "logo_url", limit: 225
    t.string "version", limit: 20, default: "1.0.0"
    t.text "features", default: [], array: true
    t.text "privacy_policy"
    t.text "terms_of_service"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "banner_photos", force: :cascade do |t|
    t.string "image_url"
    t.string "title", limit: 100
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "display_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_banner_photos_on_active"
    t.index ["display_order"], name: "index_banner_photos_on_display_order"
  end

  create_table "battle_rounds", force: :cascade do |t|
    t.bigint "battle_id", null: false
    t.integer "round_number", null: false
    t.bigint "challenger_strain_id", null: false
    t.bigint "opponent_strain_id", null: false
    t.bigint "winner_strain_id"
    t.text "round_results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id", "round_number"], name: "index_battle_rounds_on_battle_id_and_round_number", unique: true
    t.index ["battle_id"], name: "index_battle_rounds_on_battle_id"
    t.index ["challenger_strain_id"], name: "index_battle_rounds_on_challenger_strain_id"
    t.index ["opponent_strain_id"], name: "index_battle_rounds_on_opponent_strain_id"
    t.index ["winner_strain_id"], name: "index_battle_rounds_on_winner_strain_id"
    t.check_constraint "round_number >= 1 AND round_number <= 3", name: "valid_round_number"
  end

  create_table "battle_strains", force: :cascade do |t|
    t.bigint "battle_id", null: false
    t.bigint "user_id", null: false
    t.bigint "strain_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battle_id", "user_id", "position"], name: "index_battle_strains_on_battle_id_and_user_id_and_position", unique: true
    t.index ["battle_id"], name: "index_battle_strains_on_battle_id"
    t.index ["strain_id"], name: "index_battle_strains_on_strain_id"
    t.index ["user_id"], name: "index_battle_strains_on_user_id"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 3", name: "valid_position"
  end

  create_table "battles", force: :cascade do |t|
    t.bigint "challenger_id", null: false
    t.bigint "opponent_id", null: false
    t.string "status", default: "pending", null: false
    t.bigint "winner_id"
    t.integer "challenger_score", default: 0, null: false
    t.integer "opponent_score", default: 0, null: false
    t.text "battle_results"
    t.datetime "battled_at"
    t.datetime "expires_at", default: -> { "(CURRENT_TIMESTAMP + 'PT24H'::interval)" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["battled_at"], name: "index_battles_on_battled_at"
    t.index ["challenger_id", "status"], name: "index_battles_on_challenger_id_and_status"
    t.index ["challenger_id"], name: "index_battles_on_challenger_id"
    t.index ["expires_at"], name: "index_battles_on_expires_at"
    t.index ["opponent_id", "status"], name: "index_battles_on_opponent_id_and_status"
    t.index ["opponent_id"], name: "index_battles_on_opponent_id"
    t.index ["status", "created_at"], name: "index_battles_on_status_and_created_at"
    t.index ["status"], name: "index_battles_on_status"
    t.index ["winner_id"], name: "index_battles_on_winner_id"
    t.check_constraint "challenger_id <> opponent_id", name: "prevent_self_battle"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", limit: 25, null: false
    t.string "description", limit: 200
    t.string "image_url", limit: 255
    t.string "category_type", default: "strain_type", null: false
    t.boolean "active", default: true, null: false
    t.integer "strains_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_categories_on_active"
    t.index ["category_type"], name: "index_categories_on_category_type"
    t.index ["name"], name: "index_categories_on_name"
  end

  create_table "encounters", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "strain_id", null: false
    t.datetime "encountered_at", null: false
    t.integer "taste_rating", default: 0, null: false
    t.integer "smell_rating", default: 0, null: false
    t.integer "texture_rating", default: 0, null: false
    t.integer "overall_rating", default: 0, null: false
    t.integer "potency_rating", default: 0, null: false
    t.text "description"
    t.text "experience"
    t.text "effects_experienced", default: [], array: true
    t.geography "location", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.string "location_name", limit: 100
    t.string "source_type"
    t.string "source_name", limit: 100
    t.decimal "price_paid", precision: 8, scale: 2
    t.string "amount_purchased", limit: 50
    t.boolean "public", default: true, null: false
    t.boolean "friends_only", default: false, null: false
    t.string "card_image_url"
    t.boolean "card_generated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_generated"], name: "index_encounters_on_card_generated"
    t.index ["effects_experienced"], name: "index_encounters_on_effects_experienced", using: :gin
    t.index ["encountered_at"], name: "index_encounters_on_encountered_at"
    t.index ["location"], name: "index_encounters_on_location", using: :gist
    t.index ["public", "encountered_at"], name: "index_encounters_on_public_and_encountered_at"
    t.index ["public"], name: "index_encounters_on_public"
    t.index ["strain_id", "encountered_at"], name: "index_encounters_on_strain_id_and_encountered_at"
    t.index ["strain_id"], name: "index_encounters_on_strain_id"
    t.index ["user_id", "encountered_at"], name: "index_encounters_on_user_id_and_encountered_at"
    t.index ["user_id", "strain_id"], name: "unique_user_strain_encounter", unique: true
    t.index ["user_id"], name: "index_encounters_on_user_id"
    t.check_constraint "overall_rating >= 0 AND overall_rating <= 10", name: "valid_overall_rating"
    t.check_constraint "potency_rating >= 0 AND potency_rating <= 10", name: "valid_potency_rating"
    t.check_constraint "smell_rating >= 0 AND smell_rating <= 10", name: "valid_smell_rating"
    t.check_constraint "taste_rating >= 0 AND taste_rating <= 10", name: "valid_taste_rating"
    t.check_constraint "texture_rating >= 0 AND texture_rating <= 10", name: "valid_texture_rating"
  end

  create_table "friendships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "friend_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["friend_id"], name: "index_friendships_on_friend_id"
    t.index ["requested_at"], name: "index_friendships_on_requested_at"
    t.index ["status"], name: "index_friendships_on_status"
    t.index ["user_id", "friend_id"], name: "index_friendships_on_user_id_and_friend_id", unique: true
    t.index ["user_id", "status", "created_at"], name: "index_friendships_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_friendships_on_user_id"
    t.check_constraint "user_id <> friend_id", name: "prevent_self_friendship"
  end

  create_table "strain_suggestions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "suggested_name", limit: 100, null: false
    t.text "description"
    t.string "genetics"
    t.text "effects", default: [], array: true
    t.text "flavors", default: [], array: true
    t.string "status", default: "pending", null: false
    t.bigint "reviewed_by_user_id"
    t.text "admin_notes"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_strain_suggestions_on_created_at"
    t.index ["effects"], name: "index_strain_suggestions_on_effects", using: :gin
    t.index ["flavors"], name: "index_strain_suggestions_on_flavors", using: :gin
    t.index ["reviewed_by_user_id"], name: "index_strain_suggestions_on_reviewed_by_user_id"
    t.index ["status"], name: "index_strain_suggestions_on_status"
    t.index ["user_id"], name: "index_strain_suggestions_on_user_id"
  end

  create_table "strains", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.text "description"
    t.string "image_url", limit: 255
    t.bigint "category_id", null: false
    t.string "genetics"
    t.decimal "thc_percentage", precision: 5, scale: 2
    t.decimal "cbd_percentage", precision: 5, scale: 2
    t.text "effects", default: [], array: true
    t.text "flavors", default: [], array: true
    t.text "medical_uses", default: [], array: true
    t.integer "encounters_count", default: 0, null: false
    t.decimal "average_taste_rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "average_smell_rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "average_texture_rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "average_overall_rating", precision: 3, scale: 2, default: "0.0"
    t.boolean "verified", default: false
    t.string "data_source", default: "user_contributed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["average_overall_rating"], name: "index_strains_on_average_overall_rating"
    t.index ["category_id", "average_overall_rating"], name: "index_strains_on_category_id_and_average_overall_rating"
    t.index ["category_id", "verified", "average_overall_rating"], name: "idx_on_category_id_verified_average_overall_rating_cddc0163aa"
    t.index ["category_id"], name: "index_strains_on_category_id"
    t.index ["data_source"], name: "index_strains_on_data_source"
    t.index ["description"], name: "index_strains_on_description", opclass: :gin_trgm_ops, using: :gin
    t.index ["effects"], name: "index_strains_on_effects", using: :gin
    t.index ["encounters_count"], name: "index_strains_on_encounters_count"
    t.index ["flavors"], name: "index_strains_on_flavors", using: :gin
    t.index ["name"], name: "index_strains_on_name", unique: true
    t.index ["verified", "encounters_count"], name: "index_strains_on_verified_and_encounters_count"
    t.index ["verified"], name: "index_strains_on_verified"
    t.check_constraint "cbd_percentage >= 0::numeric AND cbd_percentage <= 100::numeric", name: "valid_cbd_percentage"
    t.check_constraint "thc_percentage >= 0::numeric AND thc_percentage <= 100::numeric", name: "valid_thc_percentage"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", limit: 25, null: false
    t.string "last_name", limit: 25, null: false
    t.string "username", limit: 25, null: false
    t.string "email", limit: 255, null: false
    t.string "phone", limit: 20
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "api_token"
    t.text "bio"
    t.date "date_of_birth", null: false
    t.boolean "age_verified", default: false, null: false
    t.datetime "age_verified_at"
    t.boolean "profile_public", default: true, null: false
    t.boolean "location_sharing_enabled", default: true, null: false
    t.boolean "battle_notifications", default: true, null: false
    t.integer "total_encounters", default: 0, null: false
    t.integer "battles_won", default: 0, null: false
    t.integer "battles_lost", default: 0, null: false
    t.integer "level", default: 1, null: false
    t.integer "experience_points", default: 0, null: false
    t.geography "location", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.string "city", limit: 100
    t.string "state", limit: 50
    t.string "country", limit: 50
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "email_notifications", default: true, null: false
    t.boolean "push_notifications", default: true, null: false
    t.boolean "friend_request_notifications", default: true, null: false
    t.boolean "achievement_notifications", default: true, null: false
    t.boolean "show_location_in_profile", default: false, null: false
    t.boolean "discoverable_by_username", default: true, null: false
    t.boolean "discoverable_by_location", default: true, null: false
    t.index ["age_verified"], name: "index_users_on_age_verified"
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["battles_won"], name: "index_users_on_battles_won"
    t.index ["discoverable_by_location"], name: "index_users_on_discoverable_by_location"
    t.index ["discoverable_by_username"], name: "index_users_on_discoverable_by_username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["level", "experience_points"], name: "index_users_on_level_and_experience_points"
    t.index ["location"], name: "index_users_on_location", using: :gist
    t.index ["profile_public"], name: "index_users_on_profile_public"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "achievement_progresses", "achievements"
  add_foreign_key "achievements", "users"
  add_foreign_key "activities", "users"
  add_foreign_key "battle_rounds", "battles"
  add_foreign_key "battle_rounds", "strains", column: "challenger_strain_id"
  add_foreign_key "battle_rounds", "strains", column: "opponent_strain_id"
  add_foreign_key "battle_rounds", "strains", column: "winner_strain_id"
  add_foreign_key "battle_strains", "battles"
  add_foreign_key "battle_strains", "strains"
  add_foreign_key "battle_strains", "users"
  add_foreign_key "battles", "users", column: "challenger_id"
  add_foreign_key "battles", "users", column: "opponent_id"
  add_foreign_key "battles", "users", column: "winner_id"
  add_foreign_key "encounters", "strains"
  add_foreign_key "encounters", "users"
  add_foreign_key "friendships", "users"
  add_foreign_key "friendships", "users", column: "friend_id"
  add_foreign_key "strain_suggestions", "users"
  add_foreign_key "strain_suggestions", "users", column: "reviewed_by_user_id"
  add_foreign_key "strains", "categories"
end
