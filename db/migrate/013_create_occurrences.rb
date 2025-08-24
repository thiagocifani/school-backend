class CreateOccurrences < ActiveRecord::Migration[8.0]
  def change
    create_table :occurrences do |t|
      t.references :student, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: true
      t.date :date
      t.integer :occurrence_type # enum: disciplinary, medical, positive, other
      t.string :title
      t.text :description
      t.integer :severity # enum: low, medium, high
      t.boolean :notified_guardians, default: false
      t.timestamps
    end
  end
end