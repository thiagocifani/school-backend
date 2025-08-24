FactoryBot.define do
  factory :cora_invoice do
    invoice_id { "MyString" }
    amount { "9.99" }
    status { "MyString" }
    due_date { "2025-08-22" }
    customer_name { "MyString" }
    customer_document { "MyString" }
    customer_email { "MyString" }
    boleto_url { "MyString" }
    pix_qr_code { "MyText" }
    pix_qr_code_url { "MyString" }
    invoice_type { "MyString" }
    reference_type { "MyString" }
    reference_id { 1 }
    paid_at { "2025-08-22 00:23:11" }
  end
end
