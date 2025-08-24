class StudentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    case user.role
    when 'admin', 'teacher', 'financial'
      true
    when 'guardian'
      user.guardian.students.include?(record)
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

  class Scope < Scope
    def resolve
      case user.role
      when 'admin', 'teacher', 'financial'
        scope.all
      when 'guardian'
        scope.joins(:guardian_students).where(guardian_students: { guardian_id: user.guardian.id })
      else
        scope.none
      end
    end
  end
end