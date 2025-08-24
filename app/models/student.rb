class Student < ApplicationRecord
  belongs_to :school_class, optional: true
  has_many :guardian_students, dependent: :destroy
  has_many :guardians, through: :guardian_students
  has_many :attendances, dependent: :destroy
  has_many :grades, dependent: :destroy
  has_many :occurrences, dependent: :destroy
  has_many :tuitions, dependent: :destroy
  
  enum :status, { active: 0, inactive: 1, transferred: 2 }
  enum :gender, { male: 0, female: 1, other: 2 }
  
  validates :name, presence: true
  validates :registration_number, uniqueness: true, allow_blank: true
  validates :cpf, uniqueness: true, allow_blank: true
  
  # Medical and family validations
  validates :sibling_name, presence: true, if: :has_sibling_enrolled?
  validates :specialist_details, presence: true, if: :has_specialist_monitoring?
  validates :medication_allergy_details, presence: true, if: :has_medication_allergy?
  validates :food_allergy_details, presence: true, if: :has_food_allergy?
  validates :medical_treatment_details, presence: true, if: :has_medical_treatment?
  validates :specific_medication_details, presence: true, if: :uses_specific_medication?
  
  scope :active, -> { where(status: :active) }
  
  accepts_nested_attributes_for :guardian_students, allow_destroy: true
  
  before_create :generate_registration_number
  before_save :normalize_cpf
  
  def guardians_attributes=(attributes)
    @pending_guardians = attributes
  end
  
  after_create :create_pending_guardians
  after_update :update_guardians
  
  def age
    return nil unless birth_date
    ((Date.current - birth_date) / 365.25).floor
  end
  
  private
  
  def normalize_cpf
    self.cpf = nil if cpf.blank?
  end
  
  def generate_registration_number
    return if registration_number.present?
    
    year = Date.current.year
    last_number = Student.where("registration_number LIKE ?", "#{year}%")
                         .maximum(:registration_number)
                         &.last(4)&.to_i || 0
    
    self.registration_number = "#{year}#{(last_number + 1).to_s.rjust(4, '0')}"
  end
  
  def create_pending_guardians
    return unless @pending_guardians.present?
    
    @pending_guardians.each do |guardian_data|
      next if guardian_data.blank? || guardian_data[:_destroy] == '1'
      create_new_guardian_with_user(guardian_data)
    end
    
    @pending_guardians = nil
  end
  
  def update_guardians
    return unless @pending_guardians.present?
    
    @pending_guardians.each do |guardian_data|
      next if guardian_data.blank? || guardian_data[:_destroy] == '1'
      
      # Se tem ID, é um responsável existente
      if guardian_data[:id].present?
        guardian = Guardian.find(guardian_data[:id])
        guardian.user.update!(
          name: guardian_data[:name],
          email: guardian_data[:email],
          phone: guardian_data[:phone],
          cpf: guardian_data[:cpf]
        )
        
        guardian.update!(
          birth_date: guardian_data[:birth_date],
          rg: guardian_data[:rg],
          profession: guardian_data[:profession],
          marital_status: guardian_data[:marital_status] || 'single',
          address: guardian_data[:address],
          neighborhood: guardian_data[:neighborhood],
          complement: guardian_data[:complement],
          zip_code: guardian_data[:zip_code],
          emergency_phone: guardian_data[:emergency_phone]
        )
        
        # Atualizar o relacionamento
        guardian_student = guardian_students.find_or_initialize_by(guardian: guardian)
        guardian_student.relationship = guardian_data[:relationship]
        guardian_student.save!
      else
        # É um novo responsável
        create_new_guardian_with_user(guardian_data)
      end
    end
    
    @pending_guardians = nil
  end

  def create_new_guardian_with_user(guardian_data)
    ActiveRecord::Base.transaction do
      # Criar o usuário primeiro
      user = User.create!(
        name: guardian_data[:name],
        email: guardian_data[:email],
        phone: guardian_data[:phone],
        cpf: guardian_data[:cpf],
        password: '123456', # senha padrão
        password_confirmation: '123456',
        role: 'guardian'
      )
      
      # Criar o responsável
      guardian = Guardian.create!(
        user: user,
        birth_date: guardian_data[:birth_date],
        rg: guardian_data[:rg],
        profession: guardian_data[:profession],
        marital_status: guardian_data[:marital_status] || 'single',
        address: guardian_data[:address],
        neighborhood: guardian_data[:neighborhood],
        complement: guardian_data[:complement],
        zip_code: guardian_data[:zip_code],
        emergency_phone: guardian_data[:emergency_phone]
      )
      
      # Criar o relacionamento
      guardian_students.create!(
        guardian: guardian,
        relationship: guardian_data[:relationship]
      )
    end
  end
end