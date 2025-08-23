class CreateStrains < ActiveRecord::Migration[8.0]
  def change
    create_table :strains do |t|
      t.timestamps
    end
  end
end
