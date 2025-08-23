# Fix for db/migrate/014_create_banner_photos.rb - make image_url nullable since model allows it
class CreateBannerPhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :banner_photos do |t|
      t.string :image_url  # Remove null: false since model allows attachments
      t.string :title, limit: 100
      t.text :description
      t.boolean :active, default: true, null: false
      t.integer :display_order, default: 0
      
      t.timestamps null: false
    end
    
    add_index :banner_photos, :active
    add_index :banner_photos, :display_order
  end
end