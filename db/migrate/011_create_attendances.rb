class CreateAttendances < ActiveRecord::Migration[8.0]
  def change
    create_table :attendances do |t|
      t.references :lesson, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.integer :status # enum: present, absent, late, justified
      t.text :observation
      t.timestamps
    end
  end
end