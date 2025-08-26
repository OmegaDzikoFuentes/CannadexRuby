# Fix for db/migrate/001_enable_extensions.rb
class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension "plpgsql"
    enable_extension "postgis"  # For geospatial queries
    enable_extension "pg_trgm"  # For trigram text search
  end
end
