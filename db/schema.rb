# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_23_113520) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "academic_terms", force: :cascade do |t|
    t.string "name"
    t.date "start_date"
    t.date "end_date"
    t.integer "term_type"
    t.integer "year"
    t.boolean "active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.bigint "student_id", null: false
    t.integer "status"
    t.text "observation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_attendances_on_lesson_id"
    t.index ["student_id"], name: "index_attendances_on_student_id"
  end

  create_table "class_subjects", force: :cascade do |t|
    t.bigint "school_class_id", null: false
    t.bigint "subject_id", null: false
    t.bigint "teacher_id", null: false
    t.integer "weekly_hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_class_id"], name: "index_class_subjects_on_school_class_id"
    t.index ["subject_id"], name: "index_class_subjects_on_subject_id"
    t.index ["teacher_id"], name: "index_class_subjects_on_teacher_id"
  end

  create_table "cora_invoices", force: :cascade do |t|
    t.string "invoice_id"
    t.decimal "amount"
    t.string "status"
    t.date "due_date"
    t.string "customer_name"
    t.string "customer_document"
    t.string "customer_email"
    t.string "boleto_url"
    t.text "pix_qr_code"
    t.string "pix_qr_code_url"
    t.string "invoice_type"
    t.string "reference_type"
    t.integer "reference_id"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cora_webhooks", force: :cascade do |t|
    t.string "webhook_id"
    t.string "event_type"
    t.string "invoice_id"
    t.json "payload"
    t.datetime "processed_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "diaries", force: :cascade do |t|
    t.bigint "teacher_id", null: false
    t.bigint "school_class_id", null: false
    t.bigint "subject_id", null: false
    t.bigint "academic_term_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_term_id"], name: "index_diaries_on_academic_term_id"
    t.index ["school_class_id"], name: "index_diaries_on_school_class_id"
    t.index ["status"], name: "index_diaries_on_status"
    t.index ["subject_id"], name: "index_diaries_on_subject_id"
    t.index ["teacher_id", "school_class_id", "subject_id", "academic_term_id"], name: "index_diaries_unique", unique: true
    t.index ["teacher_id"], name: "index_diaries_on_teacher_id"
  end

  create_table "education_levels", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "age_range"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_education_levels_on_name", unique: true
  end

  create_table "financial_accounts", force: :cascade do |t|
    t.string "description"
    t.decimal "amount", precision: 10, scale: 2
    t.integer "account_type"
    t.integer "category"
    t.date "date"
    t.integer "status"
    t.string "reference_type"
    t.integer "reference_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "financial_transactions", force: :cascade do |t|
    t.integer "transaction_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.date "due_date", null: false
    t.date "paid_date"
    t.integer "status", default: 0
    t.integer "payment_method"
    t.string "reference_type"
    t.integer "reference_id"
    t.text "description", null: false
    t.text "observation"
    t.decimal "discount", precision: 10, scale: 2, default: "0.0"
    t.decimal "late_fee", precision: 10, scale: 2, default: "0.0"
    t.string "external_id"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_financial_transactions_on_due_date"
    t.index ["external_id"], name: "index_financial_transactions_on_external_id"
    t.index ["paid_date"], name: "index_financial_transactions_on_paid_date"
    t.index ["reference_type", "reference_id"], name: "idx_on_reference_type_reference_id_d7bfdd5807"
    t.index ["status"], name: "index_financial_transactions_on_status"
    t.index ["transaction_type"], name: "index_financial_transactions_on_transaction_type"
  end

  create_table "grade_levels", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "education_level_id", null: false
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["education_level_id", "name"], name: "index_grade_levels_on_education_level_id_and_name", unique: true
    t.index ["education_level_id", "order"], name: "index_grade_levels_on_education_level_id_and_order", unique: true
    t.index ["education_level_id"], name: "index_grade_levels_on_education_level_id"
  end

  create_table "grades", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "class_subject_id"
    t.bigint "academic_term_id", null: false
    t.decimal "value", precision: 4, scale: 2
    t.string "grade_type"
    t.date "date"
    t.text "observation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "diary_id"
    t.bigint "lesson_id"
    t.index ["academic_term_id"], name: "index_grades_on_academic_term_id"
    t.index ["class_subject_id"], name: "index_grades_on_class_subject_id"
    t.index ["diary_id"], name: "index_grades_on_diary_id"
    t.index ["lesson_id"], name: "index_grades_on_lesson_id"
    t.index ["student_id"], name: "index_grades_on_student_id"
  end

  create_table "guardian_students", force: :cascade do |t|
    t.bigint "guardian_id", null: false
    t.bigint "student_id", null: false
    t.string "relationship"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guardian_id"], name: "index_guardian_students_on_guardian_id"
    t.index ["student_id"], name: "index_guardian_students_on_student_id"
  end

  create_table "guardians", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address"
    t.string "emergency_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "birth_date"
    t.string "rg"
    t.string "profession"
    t.integer "marital_status", default: 0
    t.string "neighborhood"
    t.string "complement"
    t.string "zip_code"
    t.index ["rg"], name: "index_guardians_on_rg", unique: true
    t.index ["user_id"], name: "index_guardians_on_user_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.date "date"
    t.string "topic"
    t.text "content"
    t.text "homework"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "diary_id", null: false
    t.integer "lesson_number"
    t.integer "duration_minutes", default: 50
    t.integer "status", default: 0
    t.index ["diary_id", "date"], name: "index_lessons_on_diary_id_and_date"
    t.index ["diary_id"], name: "index_lessons_on_diary_id"
    t.index ["lesson_number"], name: "index_lessons_on_lesson_number"
    t.index ["status"], name: "index_lessons_on_status"
  end

  create_table "occurrences", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.bigint "teacher_id", null: false
    t.date "date"
    t.integer "occurrence_type"
    t.string "title"
    t.text "description"
    t.integer "severity"
    t.boolean "notified_guardians", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "diary_id"
    t.bigint "lesson_id"
    t.index ["diary_id"], name: "index_occurrences_on_diary_id"
    t.index ["lesson_id"], name: "index_occurrences_on_lesson_id"
    t.index ["student_id"], name: "index_occurrences_on_student_id"
    t.index ["teacher_id"], name: "index_occurrences_on_teacher_id"
  end

  create_table "salaries", force: :cascade do |t|
    t.bigint "teacher_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.integer "month"
    t.integer "year"
    t.date "payment_date"
    t.integer "status"
    t.decimal "bonus", precision: 10, scale: 2
    t.decimal "deductions", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_id"], name: "index_salaries_on_teacher_id"
  end

  create_table "school_classes", force: :cascade do |t|
    t.string "name"
    t.integer "grade_level"
    t.string "section"
    t.bigint "academic_term_id"
    t.bigint "main_teacher_id"
    t.integer "max_students", default: 25
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "grade_level_id"
    t.integer "period", default: 0, null: false
    t.index ["academic_term_id"], name: "index_school_classes_on_academic_term_id"
    t.index ["grade_level_id"], name: "index_school_classes_on_grade_level_id"
    t.index ["main_teacher_id"], name: "index_school_classes_on_main_teacher_id"
    t.index ["name", "section", "academic_term_id"], name: "index_school_classes_on_name_section_term", unique: true
    t.index ["period"], name: "index_school_classes_on_period"
  end

  create_table "students", force: :cascade do |t|
    t.string "name", null: false
    t.date "birth_date"
    t.string "registration_number"
    t.integer "status", default: 0
    t.bigint "school_class_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cpf"
    t.integer "gender", default: 0
    t.string "birth_place"
    t.boolean "has_sibling_enrolled"
    t.string "sibling_name"
    t.boolean "has_specialist_monitoring"
    t.text "specialist_details"
    t.boolean "has_medication_allergy"
    t.text "medication_allergy_details"
    t.boolean "has_food_allergy"
    t.text "food_allergy_details"
    t.boolean "has_medical_treatment"
    t.text "medical_treatment_details"
    t.boolean "uses_specific_medication"
    t.text "specific_medication_details"
    t.index ["cpf"], name: "index_students_on_cpf", unique: true
    t.index ["school_class_id"], name: "index_students_on_school_class_id"
  end

  create_table "subjects", force: :cascade do |t|
    t.string "name"
    t.string "code", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "workload"
    t.index ["workload"], name: "index_subjects_on_workload"
  end

  create_table "teachers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "salary", precision: 10, scale: 2
    t.date "hire_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "specialization"
    t.integer "status", default: 0, null: false
    t.index ["status"], name: "index_teachers_on_status"
    t.index ["user_id"], name: "index_teachers_on_user_id"
  end

  create_table "tuitions", force: :cascade do |t|
    t.bigint "student_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.date "due_date"
    t.date "paid_date"
    t.integer "status"
    t.integer "payment_method"
    t.decimal "discount", precision: 10, scale: 2
    t.decimal "late_fee", precision: 10, scale: 2
    t.text "observation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_tuitions_on_student_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "name", null: false
    t.string "cpf"
    t.string "phone"
    t.integer "role", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "attendances", "lessons"
  add_foreign_key "attendances", "students"
  add_foreign_key "class_subjects", "school_classes"
  add_foreign_key "class_subjects", "subjects"
  add_foreign_key "class_subjects", "teachers"
  add_foreign_key "diaries", "academic_terms"
  add_foreign_key "diaries", "school_classes"
  add_foreign_key "diaries", "subjects"
  add_foreign_key "diaries", "teachers"
  add_foreign_key "grade_levels", "education_levels"
  add_foreign_key "grades", "academic_terms"
  add_foreign_key "grades", "class_subjects"
  add_foreign_key "grades", "diaries"
  add_foreign_key "grades", "lessons"
  add_foreign_key "grades", "students"
  add_foreign_key "guardian_students", "guardians"
  add_foreign_key "guardian_students", "students"
  add_foreign_key "guardians", "users"
  add_foreign_key "lessons", "diaries"
  add_foreign_key "occurrences", "diaries"
  add_foreign_key "occurrences", "lessons"
  add_foreign_key "occurrences", "students"
  add_foreign_key "occurrences", "teachers"
  add_foreign_key "salaries", "teachers"
  add_foreign_key "school_classes", "academic_terms"
  add_foreign_key "school_classes", "grade_levels"
  add_foreign_key "school_classes", "teachers", column: "main_teacher_id"
  add_foreign_key "students", "school_classes"
  add_foreign_key "teachers", "users"
  add_foreign_key "tuitions", "students"
end
