class AddMedicalInfoToStudents < ActiveRecord::Migration[8.0]
  def change
    add_column :students, :has_sibling_enrolled, :boolean
    add_column :students, :sibling_name, :string
    add_column :students, :has_specialist_monitoring, :boolean
    add_column :students, :specialist_details, :text
    add_column :students, :has_medication_allergy, :boolean
    add_column :students, :medication_allergy_details, :text
    add_column :students, :has_food_allergy, :boolean
    add_column :students, :food_allergy_details, :text
    add_column :students, :has_medical_treatment, :boolean
    add_column :students, :medical_treatment_details, :text
    add_column :students, :uses_specific_medication, :boolean
    add_column :students, :specific_medication_details, :text
  end
end
