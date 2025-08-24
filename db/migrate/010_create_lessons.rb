class CreateLessons < ActiveRecord::Migration[8.0]
  def change
    create_table :lessons do |t|
      t.references :class_subject, null: false, foreign_key: true
      t.date :date
      t.string :topic
      t.text :content
      t.text :homework
      t.timestamps
    end
  end
end