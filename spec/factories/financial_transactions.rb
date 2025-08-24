FactoryBot.define do
  factory :financial_transaction do
    transaction_type { 1 }
    amount { "9.99" }
    due_date { "2025-08-22" }
    paid_date { "2025-08-22" }
    status { 1 }
    payment_method { 1 }
    reference_type { "MyString" }
    reference_id { 1 }
    description { "MyText" }
    observation { "MyText" }
    discount { "9.99" }
    late_fee { "9.99" }
  end
end
