# Seeds para Diário Eletrônico
puts "🌱 Criando diários eletrônicos..."

current_term = AcademicTerm.active.first || AcademicTerm.first

# Criar diários para cada professor/turma/matéria
teachers = Teacher.includes(:user).limit(3)
classes = SchoolClass.includes(:grade_level, :academic_term).limit(4)
subjects = Subject.limit(5)

diaries_created = 0

teachers.each do |teacher|
  classes.each do |school_class|
    # Criar um diário para cada matéria que o professor pode lecionar
    subjects.sample(2).each do |subject|
      diary = Diary.find_or_create_by(
        teacher: teacher,
        school_class: school_class,
        subject: subject,
        academic_term: current_term
      ) do |d|
        d.name = "#{subject.name} - #{school_class.name} #{school_class.section}"
        d.description = "Diário de #{subject.name} para a turma #{school_class.name} #{school_class.section}"
        d.status = :active
      end
      
      if diary.persisted?
        diaries_created += 1
        
        # Criar algumas aulas para cada diário
        10.times do |i|
          lesson_date = Date.current + (i * 2).days
          
          lesson = diary.lessons.find_or_create_by(
            date: lesson_date,
            lesson_number: i + 1
          ) do |l|
            l.topic = ["Introdução", "Conceitos básicos", "Exercícios práticos", "Revisão", "Avaliação"].sample
            l.content = "Conteúdo da aula #{i + 1} sobre #{l.topic.downcase}"
            l.homework = "Exercícios da página #{rand(10..50)}"
            l.duration_minutes = [40, 45, 50].sample
            l.status = i < 5 ? :completed : :planned
          end
          
          # Criar notas para algumas aulas já concluídas
          if lesson.completed? && rand > 0.7
            diary.students.sample(rand(2..5)).each do |student|
              Grade.find_or_create_by(
                student: student,
                diary: diary,
                lesson: lesson,
                academic_term: current_term,
                date: lesson.date
              ) do |g|
                g.value = rand(6.0..10.0).round(1)
                g.grade_type = ["Prova", "Trabalho", "Participação", "Exercício"].sample
                g.observation = ["Bom desempenho", "Precisa melhorar", "Excelente", ""].sample
              end
            end
          end
          
          # Criar algumas ocorrências
          if lesson.completed? && rand > 0.8
            diary.students.sample(rand(1..2)).each do |student|
              Occurrence.find_or_create_by(
                student: student,
                teacher: teacher,
                diary: diary,
                lesson: lesson,
                date: lesson.date
              ) do |o|
                o.title = ["Boa participação", "Chegou atrasado", "Não trouxe material", "Ajudou colegas"].sample
                o.description = "Observação registrada durante a aula de #{subject.name}"
                o.occurrence_type = [:positive, :disciplinary, :other].sample
                o.severity = :low
              end
            end
          end
        end
      end
    end
  end
end

puts "✅ #{diaries_created} diários eletrônicos criados"
puts "✅ #{Lesson.count} aulas criadas"
puts "✅ #{Grade.where.not(diary_id: nil).count} notas do diário criadas"
puts "✅ #{Occurrence.where.not(diary_id: nil).count} ocorrências do diário criadas"