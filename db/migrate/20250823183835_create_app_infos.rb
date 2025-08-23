# db/migrate/015_create_app_infos.rb
class CreateAppInfos < ActiveRecord::Migration[8.0]
  def change
    create_table :app_infos do |t|
      t.string :name, limit: 100
      t.string :tagline, limit: 200
      t.text :about_text
      t.string :logo_url, limit: 225
      t.string :version, limit: 20, default: "1.0.0"
      t.text :features, array: true, default: []
      t.text :privacy_policy
      t.text :terms_of_service
      
      t.timestamps null: false
    end
  end
end