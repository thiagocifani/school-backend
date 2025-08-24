# Seeds para Sistema Escolar Infantil
# Execute com: rails db:seed

puts "🌱 Iniciando criação de dados iniciais..."

# Criar período letivo
current_year = Date.current.year
term = AcademicTerm.find_or_create_by!(
  name: "1º Bimestre #{current_year}",
  year: current_year
) do |t|
  t.start_date = Date.new(current_year, 2, 1)
  t.end_date = Date.new(current_year, 4, 30)
  t.term_type = :bimester
  t.active = true
end

puts "✅ Período letivo criado: #{term.name}"

# Criar níveis de ensino
education_levels = [
  { name: 'Educação Infantil', description: 'Para crianças de 3 a 5 anos', age_range: '3 a 5 anos' },
  { name: 'Ensino Fundamental I', description: 'Para crianças de 6 a 10 anos', age_range: '6 a 10 anos' }
].map do |level_data|
  EducationLevel.find_or_create_by!(name: level_data[:name]) do |el|
    el.description = level_data[:description]
    el.age_range = level_data[:age_range]
  end
end

puts "✅ #{education_levels.count} níveis de ensino criados"

# Criar séries
grade_levels = [
  { name: 'Infantil I', education_level: education_levels[0], order: 1 },
  { name: 'Infantil II', education_level: education_levels[0], order: 2 },
  { name: '1º Ano', education_level: education_levels[1], order: 1 },
  { name: '2º Ano', education_level: education_levels[1], order: 2 },
  { name: '3º Ano', education_level: education_levels[1], order: 3 }
].map do |grade_data|
  GradeLevel.find_or_create_by!(
    name: grade_data[:name], 
    education_level: grade_data[:education_level]
  ) do |gl|
    gl.order = grade_data[:order]
  end
end

puts "✅ #{grade_levels.count} séries criadas"

# Criar usuários administrativos
admin_user = User.find_or_create_by!(email: 'admin@escola.com') do |u|
  u.name = 'Administrador'
  u.password = 'senha123'
  u.role = :admin
  u.cpf = '123.456.789-00'
  u.phone = '(11) 99999-9999'
end

financial_user = User.find_or_create_by!(email: 'financeiro@escola.com') do |u|
  u.name = 'João Financeiro'
  u.password = 'senha123'
  u.role = :financial
  u.cpf = '987.654.321-00'
  u.phone = '(11) 88888-8888'
end

puts "✅ Usuários administrativos criados"

# Criar professores
teacher_users = [
  { name: 'Maria Silva', email: 'maria@escola.com', salary: 3500.00 },
  { name: 'João Santos', email: 'joao@escola.com', salary: 3200.00 },
  { name: 'Ana Costa', email: 'ana@escola.com', salary: 3800.00 }
]

teachers = teacher_users.map do |teacher_data|
  user = User.find_or_create_by!(email: teacher_data[:email]) do |u|
    u.name = teacher_data[:name]
    u.password = 'senha123'
    u.role = :teacher
    u.cpf = "#{rand(100..999)}.#{rand(100..999)}.#{rand(100..999)}-#{rand(10..99)}"
    u.phone = "(11) #{rand(90000..99999)}-#{rand(1000..9999)}"
  end

  Teacher.find_or_create_by!(user: user) do |t|
    t.salary = teacher_data[:salary]
    t.hire_date = 6.months.ago
    t.status = :active
    t.specialization = ['Matemática', 'Português', 'Educação Infantil', 'Artes'].sample
  end
end

puts "✅ #{teachers.count} professores criados"

# Criar matérias
subjects = [
  { name: 'Português', code: 'PORT', workload: 80 },
  { name: 'Matemática', code: 'MAT', workload: 80 },
  { name: 'Artes', code: 'ART', workload: 40 },
  { name: 'Educação Física', code: 'EDF', workload: 60 },
  { name: 'Inglês', code: 'ING', workload: 40 }
].map do |subject_data|
  Subject.find_or_create_by!(code: subject_data[:code]) do |s|
    s.name = subject_data[:name]
    s.description = "Disciplina de #{subject_data[:name]}"
    s.workload = subject_data[:workload]
  end
end

puts "✅ #{subjects.count} matérias criadas"

# Criar turmas
classes = [
  { name: 'Infantil I', grade_level: grade_levels[0], section: 'A', period: :morning },
  { name: 'Infantil II', grade_level: grade_levels[1], section: 'A', period: :morning },
  { name: '1º Ano', grade_level: grade_levels[2], section: 'A', period: :afternoon },
  { name: '2º Ano', grade_level: grade_levels[3], section: 'A', period: :afternoon }
].map do |class_data|
  SchoolClass.find_or_create_by!(
    name: class_data[:name],
    section: class_data[:section],
    academic_term: term
  ) do |c|
    c.grade_level = class_data[:grade_level]
    c.main_teacher = teachers.sample
    c.max_students = 25
    c.period = class_data[:period]
  end
end

puts "✅ #{classes.count} turmas criadas"

# Associar matérias às turmas
classes.each do |school_class|
  subjects.each do |subject|
    ClassSubject.find_or_create_by!(
      school_class: school_class,
      subject: subject
    ) do |cs|
      cs.teacher = teachers.sample
      cs.weekly_hours = rand(2..4)
    end
  end
end

puts "✅ Matérias associadas às turmas"

# Criar responsáveis
guardian_users = [
  { name: 'Carlos Oliveira', email: 'carlos@email.com' },
  { name: 'Fernanda Lima', email: 'fernanda@email.com' },
  { name: 'Roberto Silva', email: 'roberto@email.com' },
  { name: 'Patricia Santos', email: 'patricia@email.com' },
  { name: 'Eduardo Costa', email: 'eduardo@email.com' }
]

guardians = guardian_users.map do |guardian_data|
  user = User.find_or_create_by!(email: guardian_data[:email]) do |u|
    u.name = guardian_data[:name]
    u.password = 'senha123'
    u.role = :guardian
    u.cpf = "#{rand(100..999)}.#{rand(100..999)}.#{rand(100..999)}-#{rand(10..99)}"
    u.phone = "(11) #{rand(90000..99999)}-#{rand(1000..9999)}"
  end

  Guardian.find_or_create_by!(user: user) do |g|
    g.address = "Rua #{rand(1..999)}, Bairro, São Paulo - SP"
    g.emergency_phone = "(11) #{rand(90000..99999)}-#{rand(1000..9999)}"
  end
end

puts "✅ #{guardians.count} responsáveis criados"

# Criar alunos
student_names = [
  'Pedro Oliveira', 'Ana Clara Silva', 'Lucas Santos', 'Sofia Costa',
  'Miguel Lima', 'Isabella Rodrigues', 'Davi Pereira', 'Manuela Alves',
  'Arthur Ferreira', 'Helena Gomes', 'Gabriel Martins', 'Valentina Dias',
  'Bernardo Ribeiro', 'Laura Carvalho', 'Lorenzo Araújo'
]

students = student_names.map.with_index do |name, index|
  student = Student.find_or_create_by!(name: name) do |s|
    s.birth_date = rand(3..6).years.ago + rand(365).days
    s.status = :active
    s.school_class = classes.sample
  end

  # Associar responsável
  guardian = guardians[index % guardians.count]
  GuardianStudent.find_or_create_by!(
    guardian: guardian,
    student: student
  ) do |gs|
    gs.relationship = ['pai', 'mãe', 'avô', 'avó', 'tio', 'tia'].sample
  end

  student
end

puts "✅ #{students.count} alunos criados"

# Criar mensalidades
students.each do |student|
  (1..12).each do |month|
    due_date = Date.new(current_year, month, 10)
    
    tuition = Tuition.find_or_create_by!(
      student: student,
      due_date: due_date
    ) do |t|
      t.amount = rand(500..800)
      
      # Algumas mensalidades já pagas, outras pendentes
      if month <= Date.current.month && rand > 0.3
        t.status = :paid
        t.paid_date = due_date + rand(10).days
        t.payment_method = [:cash, :card, :transfer, :pix].sample
      else
        t.status = month < Date.current.month ? :overdue : :pending
      end
    end
  end
end

puts "✅ Mensalidades criadas para todos os alunos"

# Criar salários para professores
teachers.each do |teacher|
  (1..Date.current.month).each do |month|
    Salary.find_or_create_by!(
      teacher: teacher,
      month: month,
      year: current_year
    ) do |s|
      s.amount = teacher.salary
      s.bonus = rand > 0.7 ? rand(200..500) : 0
      s.deductions = rand(50..150)
      
      # Alguns salários já pagos
      if month < Date.current.month || rand > 0.5
        s.status = :paid
        s.payment_date = Date.new(current_year, month, 5)
      else
        s.status = :pending
      end
    end
  end
end

puts "✅ Salários criados para todos os professores"

# Criar algumas contas financeiras
financial_accounts = [
  { description: 'Conta de Luz', amount: 450.00, account_type: :expense, category: :utility },
  { description: 'Conta de Água', amount: 280.00, account_type: :expense, category: :utility },
  { description: 'Material Escolar', amount: 1200.00, account_type: :expense, category: :supply },
  { description: 'Taxa de Matrícula', amount: 200.00, account_type: :income, category: :enrollment_fee },
  { description: 'Manutenção Predial', amount: 800.00, account_type: :expense, category: :maintenance }
]

financial_accounts.each do |account_data|
  FinancialAccount.find_or_create_by!(
    description: account_data[:description],
    date: rand(30.days).seconds.ago
  ) do |fa|
    fa.amount = account_data[:amount]
    fa.account_type = account_data[:account_type]
    fa.category = account_data[:category]
    fa.status = :paid
  end
end

puts "✅ #{financial_accounts.count} contas financeiras criadas"

puts "\n🎉 Seeds executados com sucesso!"
puts "\n📊 Resumo dos dados criados:"
puts "   • #{AcademicTerm.count} período(s) letivo(s)"
puts "   • #{EducationLevel.count} nível(is) de ensino"
puts "   • #{GradeLevel.count} série(s)"
puts "   • #{User.count} usuário(s)"
puts "   • #{Teacher.count} professor(es)"
puts "   • #{Guardian.count} responsável(is)"
puts "   • #{Student.count} aluno(s)"
puts "   • #{SchoolClass.count} turma(s)"
puts "   • #{Subject.count} matéria(s)"
puts "   • #{ClassSubject.count} disciplina(s) por turma"
puts "   • #{Tuition.count} mensalidade(s)"
puts "   • #{Salary.count} salário(s)"
puts "   • #{FinancialAccount.count} conta(s) financeira(s)"
puts "\n🔑 Credenciais de acesso:"
puts "   Admin: admin@escola.com / senha123"
puts "   Financeiro: financeiro@escola.com / senha123"
puts "   Professores: maria@escola.com, joao@escola.com, ana@escola.com / senha123"
puts "   Responsáveis: carlos@email.com, fernanda@email.com, etc. / senha123"
