class CreateClassSubjects < ActiveRecord::Migration[8.0]
  def change
    create_table :class_subjects do |t|
      t.references :school_class, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: true
      t.integer :weekly_hours
      t.timestamps
    end
  end
end