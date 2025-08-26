class FinancialTransactionPolicy < ApplicationPolicy
  def index?
    admin_or_financial?
  end

  def show?
    case user.role
    when 'admin', 'financial'
      true
    when 'teacher'
      # Teachers can see their own salary transactions
      if record.salary? && record.reference
        case record.reference_type
        when 'Teacher'
          record.reference.user == user
        when 'Salary'
          record.reference.teacher.user == user
        else
          false
        end
      else
        false
      end
    when 'guardian'
      # Guardians can see tuition transactions for their students
      record.tuition? && record.reference && user.guardian.students.include?(record.reference)
    else
      false
    end
  end

  def create?
    admin_or_financial?
  end

  def update?
    admin_or_financial?
  end

  def destroy?
    admin?
  end

  def pay?
    case user.role
    when 'admin', 'financial'
      true
    when 'guardian'
      # Guardians can pay tuitions for their students
      record.tuition? && record.reference && user.guardian.students.include?(record.reference)
    else
      false
    end
  end

  def generate_cora_invoice?
    admin_or_financial?
  end

  def bulk_create_tuitions?
    admin_or_financial?
  end

  def bulk_create_salaries?
    admin_or_financial?
  end

  def cash_flow?
    admin_or_financial?
  end

  def statistics?
    admin_or_financial?
  end

  class Scope < Scope
    def resolve
      case user.role
      when 'admin', 'financial'
        scope.all
      when 'teacher'
        # Teachers can see their own salary transactions
        teacher_id = user.teacher.id
        salary_ids = Salary.where(teacher_id: teacher_id).pluck(:id)
        
        scope.where(
          transaction_type: :salary
        ).where(
          "(reference_type = 'Teacher' AND reference_id = ?) OR (reference_type = 'Salary' AND reference_id IN (?))",
          teacher_id,
          salary_ids.any? ? salary_ids : [0] # Avoid empty array issue
        )
      when 'guardian'
        # Guardians can see tuition transactions for their students
        student_ids = user.guardian.students.pluck(:id)
        scope.where(transaction_type: :tuition, reference_type: 'Student', reference_id: student_ids)
      else
        scope.none
      end
    end
  end
end