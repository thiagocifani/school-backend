Rails.application.routes.draw do
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/validate', to: 'auth#validate_token'
      
      # Students
      resources :students do
        member do
          get :report
        end
      end
      
      # Teachers
      resources :teachers
      
      # Academic Terms (Etapas)
      resources :academic_terms do
        member do
          put :set_active
        end
      end
      
      # Education Levels (Níveis de Ensino)
      resources :education_levels
      
      # Grade Levels (Séries)
      resources :grade_levels
      
      # School Classes (Turmas)
      resources :classes do
        resources :students, only: [:index]
      end
      
      # Subjects (Disciplinas)
      resources :subjects
      
      # Diaries (Diários Eletrônicos)
      resources :diaries do
        member do
          get :students
          get :statistics
        end
        resources :lessons do
          member do
            get :attendances
            put :update_attendances
            put :complete_lesson
            put :cancel_lesson
          end
        end
      end
      
      # Lessons
      resources :lessons do
        resources :attendances, only: [:index]
      end
      
      # Attendances
      resources :attendances, only: [:index, :update] do
        collection do
          put :bulk_update
          get :report
        end
      end
      
      # Grades
      resources :grades do
        collection do
          get :report
        end
      end
      
      # Occurrences
      resources :occurrences
      
      # Salaries
      resources :salaries do
        member do
          put :pay
          post :generate_cora_pix
        end
        collection do
          post :bulk_generate
          get :statistics
        end
      end
      
      # Tuitions (Mensalidades)
      resources :tuitions do
        member do
          put :pay
          post :generate_boleto
        end
        collection do
          post :bulk_generate
          get :statistics
          get :overdue_report
        end
      end
      
      # Payments (Cora Integration)
      resources :payments, only: [:index, :show, :destroy] do
        member do
          put :cancel
        end
        collection do
          post :create_tuition_boleto
          post :create_salary_pix
          post :create_expense_payment
          get :stats
        end
      end
      
      # Cora Webhooks
      resources :cora_webhooks, only: [:index, :show] do
        member do
          put :retry
        end
        collection do
          post :receive
        end
      end
      
      # Financial Transactions (Unified)
      resources :financial_transactions do
        member do
          put :pay
          post :generate_cora_invoice
        end
        collection do
          post :bulk_create_tuitions
          post :bulk_create_salaries
          get :cash_flow
          get :statistics
        end
      end
      
      # Cora Invoices
      resources :cora_invoices do
        member do
          post :generate_pix_voucher
          post :generate_boleto
          patch :cancel
        end
        collection do
          get :by_transaction
        end
      end
      
      # Finances
      namespace :finances do
        get :dashboard
        get :tuitions
        put 'tuitions/:id', to: 'finances#update_tuition'
        get :salaries
        put 'salaries/:id', to: 'finances#update_salary'
        get :financial_accounts
        post :financial_accounts, to: 'finances#create_financial_account'
        get :reports
      end
      
      # Reports
      resources :reports, only: [] do
        collection do
          get :student_report
          get :attendance_report
          get :financial_report
          get :grades_report
        end
      end
      
      # Dashboard
      get :dashboard, to: 'dashboard#index'
      
      # Admin routes
      namespace :admin do
        resources :students do
          member do
            get :report
          end
          collection do
            post :bulk_import
            get :export
          end
        end
        
        resources :guardians do
          member do
            get :students
          end
        end
        
        resources :teachers do
          collection do
            post :bulk_import
            get :export
          end
        end
        
        resources :users do
          member do
            put :change_role
            put :reset_password
          end
        end
        
        resources :classes do
          member do
            post :bulk_add_students
            delete :remove_student
          end
        end
        
        get :dashboard, to: 'admin_dashboard#index'
        get :reports, to: 'admin_reports#index'
        get :system_stats, to: 'admin_dashboard#system_stats'
      end
    end
  end
end
