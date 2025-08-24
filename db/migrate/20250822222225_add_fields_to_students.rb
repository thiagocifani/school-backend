class AddFieldsToStudents < ActiveRecord::Migration[8.0]
  def change
    add_column :students, :cpf, :string
    add_column :students, :gender, :integer, default: 0 # enum: male, female, other
    add_column :students, :birth_place, :string
    
    add_index :students, :cpf, unique: true
  end
end
