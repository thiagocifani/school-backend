class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  enum :role, { admin: 0, teacher: 1, guardian: 2, financial: 3 }
  
  has_one :teacher, dependent: :destroy
  has_one :guardian, dependent: :destroy
  
  validates :name, presence: true
  validates :cpf, uniqueness: true, allow_blank: true
end