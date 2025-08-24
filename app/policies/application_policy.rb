class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin_or_financial?
  end

  def new?
    create?
  end

  def update?
    admin_or_financial?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user&.admin?
  end

  def teacher?
    user&.teacher?
  end

  def guardian?
    user&.guardian?
  end

  def financial?
    user&.financial?
  end

  def admin_or_financial?
    admin? || financial?
  end

  def admin_or_teacher?
    admin? || teacher?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end