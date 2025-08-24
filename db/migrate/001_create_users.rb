class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :encrypted_password, null: false
      t.string :name, null: false
      t.string :cpf
      t.string :phone
      t.integer :role, default: 0 # enum: admin, teacher, guardian, financial
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :cpf, unique: true
  end
end