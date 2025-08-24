class CreateGrades < ActiveRecord::Migration[8.0]
  def change
    create_table :grades do |t|
      t.references :student, null: false, foreign_key: true
      t.references :class_subject, null: false, foreign_key: true
      t.references :academic_term, null: false, foreign_key: true
      t.decimal :value, precision: 4, scale: 2
      t.string :grade_type # "Prova 1", "Trabalho", "Participação"
      t.date :date
      t.text :observation
      t.timestamps
    end
  end
end