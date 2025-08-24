class ReportGenerator
  def initialize(object, term = nil)
    @object = object
    @term = term
  end
  
  def generate_student_report
    student = @object
    
    {
      student: {
        name: student.name,
        registration: student.registration_number,
        class: student.school_class&.full_name
      },
      term: {
        name: @term.name,
        period: "#{@term.start_date} - #{@term.end_date}"
      },
      grades: compile_grades(student),
      attendance: compile_attendance(student),
      occurrences: compile_occurrences(student)
    }
  end
  
  def generate_attendance_report(start_date, end_date)
    school_class = @object
    
    students = school_class.students.active.includes(:attendances)
    attendances = Attendance.joins(:lesson, :student)
                           .where(lessons: { date: start_date..end_date })
                           .where(students: { school_class_id: school_class.id })
    
    {
      class: {
        name: school_class.full_name,
        teacher: school_class.main_teacher&.name
      },
      period: "#{start_date} - #{end_date}",
      summary: attendance_summary(attendances),
      students: students.map { |student| student_attendance_data(student, start_date, end_date) }
    }
  end
  
  def generate_financial_report(start_date, end_date)
    {
      period: "#{start_date} - #{end_date}",
      income: income_data(start_date, end_date),
      expenses: expenses_data(start_date, end_date),
      balance: calculate_balance(start_date, end_date),
      tuitions: tuitions_data(start_date, end_date),
      salaries: salaries_data(start_date, end_date)
    }
  end
  
  private
  
  def compile_grades(student)
    student.grades.where(academic_term: @term)
           .includes(:class_subject)
           .group_by { |g| g.class_subject.subject.name }
           .transform_values do |grades|
      {
        grades: grades.map { |g| { type: g.grade_type, value: g.value, date: g.date } },
        average: grades.average(:value)&.round(2)
      }
    end
  end
  
  def compile_attendance(student)
    attendances = student.attendances.joins(:lesson)
                        .where(lessons: { date: @term.start_date..@term.end_date })
    
    total = attendances.count
    present = attendances.present.count
    absent = attendances.absent.count
    late = attendances.late.count
    justified = attendances.justified.count
    
    {
      total_classes: total,
      present: present,
      absent: absent,
      late: late,
      justified: justified,
      percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
    }
  end
  
  def compile_occurrences(student)
    student.occurrences.where(date: @term.start_date..@term.end_date)
           .includes(:teacher)
           .map do |occurrence|
      {
        date: occurrence.date,
        type: occurrence.occurrence_type,
        title: occurrence.title,
        description: occurrence.description,
        severity: occurrence.severity,
        teacher: occurrence.teacher.name
      }
    end
  end
  
  def attendance_summary(attendances)
    total = attendances.count
    present = attendances.present.count
    
    {
      total_classes: total,
      total_present: present,
      total_absent: total - present,
      overall_percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
    }
  end
  
  def student_attendance_data(student, start_date, end_date)
    attendances = student.attendances.for_period(start_date, end_date)
    total = attendances.count
    present = attendances.present.count
    
    {
      student: {
        name: student.name,
        registration: student.registration_number
      },
      total_classes: total,
      present: present,
      absent: total - present,
      percentage: total > 0 ? (present.to_f / total * 100).round(2) : 0
    }
  end
  
  def income_data(start_date, end_date)
    income_accounts = FinancialAccount.income.paid.for_period(start_date, end_date)
    tuitions_paid = Tuition.paid.where(paid_date: start_date..end_date)
    
    {
      total: income_accounts.sum(:amount) + tuitions_paid.sum { |t| t.total_amount },
      accounts: income_accounts.sum(:amount),
      tuitions: tuitions_paid.sum { |t| t.total_amount },
      by_category: income_accounts.group(:category).sum(:amount)
    }
  end
  
  def expenses_data(start_date, end_date)
    expense_accounts = FinancialAccount.expense.paid.for_period(start_date, end_date)
    salaries_paid = Salary.paid.where(payment_date: start_date..end_date)
    
    {
      total: expense_accounts.sum(:amount) + salaries_paid.sum { |s| s.total_amount },
      accounts: expense_accounts.sum(:amount),
      salaries: salaries_paid.sum { |s| s.total_amount },
      by_category: expense_accounts.group(:category).sum(:amount)
    }
  end
  
  def calculate_balance(start_date, end_date)
    income = income_data(start_date, end_date)[:total]
    expenses = expenses_data(start_date, end_date)[:total]
    income - expenses
  end
  
  def tuitions_data(start_date, end_date)
    tuitions = Tuition.where(due_date: start_date..end_date)
    
    {
      total_due: tuitions.sum(:amount),
      total_paid: tuitions.paid.sum { |t| t.total_amount },
      pending_count: tuitions.pending.count,
      overdue_count: tuitions.overdue.count,
      collection_rate: tuitions.count > 0 ? (tuitions.paid.count.to_f / tuitions.count * 100).round(2) : 0
    }
  end
  
  def salaries_data(start_date, end_date)
    # Para salários, vamos considerar o mês/ano dentro do período
    start_month = start_date.month
    start_year = start_date.year
    end_month = end_date.month
    end_year = end_date.year
    
    salaries = Salary.where(
      "(year = ? AND month >= ?) OR (year = ? AND month <= ?) OR (year > ? AND year < ?)",
      start_year, start_month, end_year, end_month, start_year, end_year
    )
    
    {
      total_due: salaries.sum { |s| s.total_amount },
      total_paid: salaries.paid.sum { |s| s.total_amount },
      pending_count: salaries.pending.count
    }
  end
end