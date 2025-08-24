class CreateGuardians < ActiveRecord::Migration[8.0]
  def change
    create_table :guardians do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address
      t.string :emergency_phone
      t.timestamps
    end
  end
end