class UpdateGradesAndOccurrencesForDiary < ActiveRecord::Migration[8.0]
  def change
    # Update Grades table
    add_reference :grades, :diary, null: true, foreign_key: true unless column_exists?(:grades, :diary_id)
    add_reference :grades, :lesson, null: true, foreign_key: true unless column_exists?(:grades, :lesson_id)
    
    # Update Occurrences table  
    add_reference :occurrences, :diary, null: true, foreign_key: true unless column_exists?(:occurrences, :diary_id)
    add_reference :occurrences, :lesson, null: true, foreign_key: true unless column_exists?(:occurrences, :lesson_id)
    
    # Add indexes only if they don't exist
    add_index :grades, :diary_id unless index_exists?(:grades, :diary_id)
    add_index :grades, :lesson_id unless index_exists?(:grades, :lesson_id)
    add_index :occurrences, :diary_id unless index_exists?(:occurrences, :diary_id)
    add_index :occurrences, :lesson_id unless index_exists?(:occurrences, :lesson_id)
  end
end