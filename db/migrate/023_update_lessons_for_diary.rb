class UpdateLessonsForDiary < ActiveRecord::Migration[8.0]
  def change
    # Remove old foreign key if exists
    remove_foreign_key :lessons, :class_subjects if foreign_key_exists?(:lessons, :class_subjects)
    
    # Add new relationships
    add_reference :lessons, :diary, null: false, foreign_key: true
    add_column :lessons, :lesson_number, :integer
    add_column :lessons, :duration_minutes, :integer, default: 50
    add_column :lessons, :status, :integer, default: 0 # enum: planned, completed, cancelled
    
    # Remove old class_subject_id
    remove_column :lessons, :class_subject_id, :bigint if column_exists?(:lessons, :class_subject_id)
    
    add_index :lessons, [:diary_id, :date]
    add_index :lessons, :lesson_number
    add_index :lessons, :status
  end
end