FactoryBot.define do
  factory :cora_webhook do
    webhook_id { "MyString" }
    event_type { "MyString" }
    invoice_id { "MyString" }
    payload { "" }
    processed_at { "2025-08-22 00:23:46" }
    status { "MyString" }
  end
end
