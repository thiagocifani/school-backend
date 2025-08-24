class CreateCoraWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :cora_webhooks do |t|
      t.string :webhook_id
      t.string :event_type
      t.string :invoice_id
      t.json :payload
      t.datetime :processed_at
      t.string :status

      t.timestamps
    end
  end
end
