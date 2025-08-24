class MakeClassSubjectOptionalInGrades < ActiveRecord::Migration[8.0]
  def change
    change_column_null :grades, :class_subject_id, true
  end
end