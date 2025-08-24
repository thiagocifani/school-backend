require 'prawn'
require 'prawn/table'

class PdfExporter
  def export_student_report(data)
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header
      pdf.text "BOLETIM ESCOLAR", size: 20, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "Sistema Escolar Infantil", size: 12, align: :center
      pdf.move_down 20
      
      # Student Info
      pdf.text "Aluno: #{data[:student][:name]}", size: 14, style: :bold
      pdf.text "Matrícula: #{data[:student][:registration]}", size: 12
      pdf.text "Turma: #{data[:student][:class]}", size: 12
      pdf.text "Período: #{data[:term][:period]}", size: 12
      pdf.move_down 20
      
      # Grades Section
      if data[:grades].any?
        pdf.text "NOTAS POR DISCIPLINA", size: 14, style: :bold
        pdf.move_down 10
        
        grades_data = [["Disciplina", "Avaliações", "Média"]]
        data[:grades].each do |subject, info|
          grades_text = info[:grades].map { |g| "#{g[:type]}: #{g[:value]}" }.join("\n")
          grades_data << [subject, grades_text, info[:average] || "N/A"]
        end
        
        pdf.table(grades_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = "EEEEEE"
          cells.padding = 8
          cells.borders = [:top, :bottom, :left, :right]
        end
        
        pdf.move_down 20
      end
      
      # Attendance Section
      pdf.text "FREQUÊNCIA", size: 14, style: :bold
      pdf.move_down 10
      
      attendance = data[:attendance]
      attendance_data = [
        ["Total de Aulas", attendance[:total_classes]],
        ["Presenças", attendance[:present]],
        ["Faltas", attendance[:absent]],
        ["Atrasos", attendance[:late]],
        ["Faltas Justificadas", attendance[:justified]],
        ["Percentual de Presença", "#{attendance[:percentage]}%"]
      ]
      
      pdf.table(attendance_data, width: pdf.bounds.width / 2) do
        cells.padding = 6
        cells.borders = [:top, :bottom, :left, :right]
        column(0).font_style = :bold
      end
      
      pdf.move_down 20
      
      # Occurrences Section
      if data[:occurrences].any?
        pdf.text "OCORRÊNCIAS", size: 14, style: :bold
        pdf.move_down 10
        
        data[:occurrences].each do |occurrence|
          pdf.text "#{occurrence[:date]} - #{occurrence[:title]}", style: :bold
          pdf.text "Tipo: #{occurrence[:type].humanize} | Severidade: #{occurrence[:severity].humanize}"
          pdf.text "Professor: #{occurrence[:teacher]}"
          pdf.text occurrence[:description]
          pdf.move_down 10
        end
      end
      
      # Footer
      pdf.move_cursor_to 50
      pdf.text "Data de Emissão: #{Date.current.strftime('%d/%m/%Y')}", size: 10, align: :right
      pdf.text "Sistema Escolar - Relatório gerado automaticamente", size: 8, align: :center
    end.render
  end
  
  def export_attendance_report(data)
    Prawn::Document.new(page_size: 'A4', margin: 40, page_layout: :landscape) do |pdf|
      # Header
      pdf.text "RELATÓRIO DE FREQUÊNCIA", size: 18, style: :bold, align: :center
      pdf.move_down 5
      pdf.text "Turma: #{data[:class][:name]}", size: 14, align: :center
      pdf.text "Professor: #{data[:class][:teacher]}", size: 12, align: :center
      pdf.text "Período: #{data[:period]}", size: 12, align: :center
      pdf.move_down 20
      
      # Summary
      summary = data[:summary]
      pdf.text "RESUMO GERAL", size: 14, style: :bold
      pdf.text "Total de Aulas: #{summary[:total_classes]} | " \
               "Presenças: #{summary[:total_present]} | " \
               "Faltas: #{summary[:total_absent]} | " \
               "Frequência Geral: #{summary[:overall_percentage]}%"
      pdf.move_down 15
      
      # Students Table
      pdf.text "FREQUÊNCIA POR ALUNO", size: 14, style: :bold
      pdf.move_down 10
      
      if data[:students].any?
        table_data = [["Aluno", "Matrícula", "Total Aulas", "Presenças", "Faltas", "Frequência %"]]
        
        data[:students].each do |student_data|
          table_data << [
            student_data[:student][:name],
            student_data[:student][:registration],
            student_data[:total_classes],
            student_data[:present],
            student_data[:absent],
            "#{student_data[:percentage]}%"
          ]
        end
        
        pdf.table(table_data, header: true, width: pdf.bounds.width) do
          row(0).font_style = :bold
          row(0).background_color = "EEEEEE"
          cells.padding = 6
          cells.borders = [:top, :bottom, :left, :right]
          cells.align = :center
          column(0).align = :left  # Nome do aluno alinhado à esquerda
        end
      end
      
      # Footer
      pdf.move_cursor_to 40
      pdf.text "Data de Emissão: #{Date.current.strftime('%d/%m/%Y')}", size: 10, align: :right
    end.render
  end
  
  def export_financial_report(data)
    Prawn::Document.new(page_size: 'A4', margin: 40) do |pdf|
      # Header
      pdf.text "RELATÓRIO FINANCEIRO", size: 18, style: :bold, align: :center
      pdf.move_down 5
      pdf.text "Período: #{data[:period]}", size: 14, align: :center
      pdf.move_down 20
      
      # Summary
      pdf.text "RESUMO FINANCEIRO", size: 14, style: :bold
      pdf.move_down 10
      
      summary_data = [
        ["Receitas Totais", "R$ #{data[:income][:total].to_s(:currency)}"],
        ["Despesas Totais", "R$ #{data[:expenses][:total].to_s(:currency)}"],
        ["Saldo do Período", "R$ #{data[:balance].to_s(:currency)}"]
      ]
      
      pdf.table(summary_data, width: pdf.bounds.width / 2) do
        cells.padding = 8
        cells.borders = [:top, :bottom, :left, :right]
        column(0).font_style = :bold
        
        # Colorir saldo baseado no valor
        if data[:balance] >= 0
          row(2).background_color = "E8F5E8"  # Verde claro
        else
          row(2).background_color = "FFF2F2"  # Vermelho claro
        end
      end
      
      pdf.move_down 20
      
      # Income Breakdown
      pdf.text "RECEITAS POR CATEGORIA", size: 14, style: :bold
      pdf.move_down 10
      
      income_data = [["Categoria", "Valor"]]
      income_data << ["Mensalidades", "R$ #{data[:income][:tuitions].to_s(:currency)}"]
      income_data << ["Outras Receitas", "R$ #{data[:income][:accounts].to_s(:currency)}"]
      
      pdf.table(income_data, header: true, width: pdf.bounds.width / 2) do
        row(0).font_style = :bold
        row(0).background_color = "EEEEEE"
        cells.padding = 6
      end
      
      pdf.move_down 20
      
      # Expenses Breakdown
      pdf.text "DESPESAS POR CATEGORIA", size: 14, style: :bold
      pdf.move_down 10
      
      expense_data = [["Categoria", "Valor"]]
      expense_data << ["Salários", "R$ #{data[:expenses][:salaries].to_s(:currency)}"]
      expense_data << ["Outras Despesas", "R$ #{data[:expenses][:accounts].to_s(:currency)}"]
      
      pdf.table(expense_data, header: true, width: pdf.bounds.width / 2) do
        row(0).font_style = :bold
        row(0).background_color = "EEEEEE"
        cells.padding = 6
      end
      
      pdf.move_down 20
      
      # Tuitions Summary
      tuitions = data[:tuitions]
      pdf.text "SITUAÇÃO DAS MENSALIDADES", size: 14, style: :bold
      pdf.move_down 10
      
      tuition_data = [
        ["Total a Receber", "R$ #{tuitions[:total_due].to_s(:currency)}"],
        ["Total Recebido", "R$ #{tuitions[:total_paid].to_s(:currency)}"],
        ["Mensalidades Pendentes", tuitions[:pending_count]],
        ["Mensalidades em Atraso", tuitions[:overdue_count]],
        ["Taxa de Cobrança", "#{tuitions[:collection_rate]}%"]
      ]
      
      pdf.table(tuition_data, width: pdf.bounds.width / 2) do
        cells.padding = 6
        column(0).font_style = :bold
      end
      
      # Footer
      pdf.move_cursor_to 50
      pdf.text "Data de Emissão: #{Date.current.strftime('%d/%m/%Y')}", size: 10, align: :right
    end.render
  end
end