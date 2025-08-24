class CreateCoraInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :cora_invoices do |t|
      t.string :invoice_id
      t.decimal :amount
      t.string :status
      t.date :due_date
      t.string :customer_name
      t.string :customer_document
      t.string :customer_email
      t.string :boleto_url
      t.text :pix_qr_code
      t.string :pix_qr_code_url
      t.string :invoice_type
      t.string :reference_type
      t.integer :reference_id
      t.datetime :paid_at

      t.timestamps
    end
  end
end
