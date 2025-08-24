class CreateDiaries < ActiveRecord::Migration[8.0]
  def change
    create_table :diaries do |t|
      t.references :teacher, null: false, foreign_key: true
      t.references :school_class, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :academic_term, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false # enum: active, completed, archived
      
      t.timestamps
    end
    
    add_index :diaries, [:teacher_id, :school_class_id, :subject_id, :academic_term_id], 
              unique: true, name: 'index_diaries_unique'
    add_index :diaries, :status
  end
end