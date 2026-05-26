class CreateStrainIdentifications < ActiveRecord::Migration[8.0]
  def change
    create_table :strain_identifications do |t|
      t.timestamps
    end
  end
end
