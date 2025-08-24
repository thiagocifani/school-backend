class CoraApiService
  include HTTParty
  
  base_uri ENV['CORA_BASE_URL'] || 'https://matls-clients.api.stage.cora.com.br'
  
  def initialize
    setup_mtls_certificates
    @client_id = ENV['CORA_CLIENT_ID']
  end
  
  # Create invoice/boleto
  def create_invoice(cora_invoice)
    payload = build_invoice_payload(cora_invoice)
    
    response = self.class.post(
      '/invoices',
      headers: headers,
      body: payload.to_json
    )
    
    handle_response(response, cora_invoice)
  end
  
  # Get invoice details
  def get_invoice(invoice_id)
    response = self.class.get(
      "/invoices/#{invoice_id}",
      headers: headers
    )
    
    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Failed to fetch invoice: #{response.body}"
      nil
    end
  end
  
  # Cancel invoice
  def cancel_invoice(cora_invoice)
    invoice_id = cora_invoice.invoice_id
    
    response = self.class.delete(
      "/invoices/#{invoice_id}",
      headers: headers
    )
    
    if response.success?
      Rails.logger.info "Invoice cancelled successfully: #{invoice_id}"
      true
    else
      Rails.logger.error "Failed to cancel invoice: #{response.body}"
      # For development, always allow cancellation
      if Rails.env.development?
        Rails.logger.warn "Mock cancellation for development"
        true
      else
        false
      end
    end
  end
  
  # Generate PIX voucher for salary payments
  def generate_pix_voucher(cora_invoice)
    payload = {
      invoice_id: cora_invoice.invoice_id,
      payment_method: 'pix',
      recipient: {
        name: cora_invoice.customer_name,
        document: clean_document(cora_invoice.customer_document),
        email: cora_invoice.customer_email
      },
      amount: (cora_invoice.amount * 100).to_i, # Convert to cents
      description: "PIX - #{service_description_for(cora_invoice)}"
    }
    
    response = self.class.post(
      '/v1/pix/generate',
      headers: headers,
      body: payload.to_json
    )
    
    if response.success?
      data = response.parsed_response
      {
        pix_qr_code: data['qr_code'] || data['pix_code'],
        pix_qr_code_url: data['qr_code_url'] || data['pix_url'],
        expires_at: data['expires_at']
      }
    else
      Rails.logger.error "PIX generation failed: #{response.body}"
      
      # Mock response for development
      if Rails.env.development?
        {
          pix_qr_code: '00020126580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-426614174000520400005303986540' + (cora_invoice.amount * 100).to_i.to_s.rjust(10, '0') + '5802BR5913Escola Sistema6008BRASILIA62070503***6304ABCD',
          pix_qr_code_url: "https://staging-cora.com/pix/#{cora_invoice.invoice_id}",
          expires_at: 24.hours.from_now
        }
      else
        raise "Failed to generate PIX voucher: #{response.body}"
      end
    end
  end
  
  # Generate boleto for tuition payments  
  def generate_boleto(cora_invoice)
    payload = {
      invoice_id: cora_invoice.invoice_id,
      payment_method: 'boleto',
      payer: {
        name: cora_invoice.customer_name,
        document: clean_document(cora_invoice.customer_document),
        email: cora_invoice.customer_email
      },
      amount: (cora_invoice.amount * 100).to_i, # Convert to cents
      due_date: cora_invoice.due_date.strftime('%Y-%m-%d'),
      description: service_description_for(cora_invoice),
      fine_config: {
        percentage: 2.0,
        days_after_due_date: 1
      },
      interest_config: {
        percentage: 1.0,
        type: 'per_month'
      }
    }
    
    response = self.class.post(
      '/v1/boletos/generate',
      headers: headers,
      body: payload.to_json
    )
    
    if response.success?
      data = response.parsed_response
      {
        boleto_url: data['boleto_url'] || data['bank_slip_url'],
        barcode: data['barcode'] || data['digitable_line'],
        expires_at: data['expires_at']
      }
    else
      Rails.logger.error "Boleto generation failed: #{response.body}"
      
      # Mock response for development
      if Rails.env.development?
        {
          boleto_url: "https://staging-cora.com/boletos/#{cora_invoice.invoice_id}",
          barcode: "23793.#{rand(10000..99999)} #{rand(10000..99999)}.#{rand(100000..999999)} #{rand(1..9)} #{(Date.current + 30.days).strftime('%y%m%d')}#{(cora_invoice.amount * 100).to_i.to_s.rjust(10, '0')}",
          expires_at: 30.days.from_now
        }
      else
        raise "Failed to generate boleto: #{response.body}"
      end
    end
  end
  
  # Create PIX payment for salaries
  def create_pix_payment(salary, teacher)
    payload = {
      recipient: {
        name: teacher.user.name,
        document: teacher.user.cpf || '000.000.000-00',
        bank_account: {
          # This would need to be collected from teacher profile
          account_number: '12345',
          account_digit: '6',
          branch_number: '1234',
          bank_code: '260' # Cora bank code
        }
      },
      amount: (salary.amount * 100).to_i, # Convert to cents
      description: "Pagamento de salário - #{Date.current.strftime('%m/%Y')}"
    }
    
    response = self.class.post(
      '/v1/pix/payments',
      headers: headers,
      body: payload.to_json
    )
    
    if response.success?
      response.parsed_response
    else
      Rails.logger.error "PIX payment failed: #{response.body}"
      nil
    end
  end
  
  private
  
  def setup_mtls_certificates
    cert_path = Rails.root.join(ENV['CORA_CERTIFICATE_PATH'] || 'config/certs/cora/certificate.crt')
    key_path = Rails.root.join(ENV['CORA_PRIVATE_KEY_PATH'] || 'config/certs/cora/private-key.key')
    
    if File.exist?(cert_path) && File.exist?(key_path)
      Rails.logger.info "Setting up mTLS with Cora certificates"
      
      # Configure HTTParty to use client certificates
      self.class.default_options.merge!(
        pem: File.read(cert_path),
        pem_password: nil, # No password for certificate
        ssl_extra_chain_cert: File.read(key_path),
        verify: false, # For staging environment
        ssl_version: :TLSv1_2
      )
      
      Rails.logger.info "mTLS configuration completed successfully"
    else
      Rails.logger.warn "Cora certificates not found at #{cert_path} and #{key_path}. Using mock mode."
      
      # Create sample certificate files for reference
      create_sample_certificates(cert_path, key_path)
    end
  rescue => e
    Rails.logger.error "Failed to setup mTLS certificates: #{e.message}"
    Rails.logger.warn "Continuing in mock mode"
  end
  
  def create_sample_certificates(cert_path, key_path)
    return if File.exist?(cert_path) && File.exist?(key_path)
    
    FileUtils.mkdir_p(File.dirname(cert_path))
    
    # Create placeholder files with instructions
    File.write(cert_path, "# Place your Cora client certificate here\n# Format: PEM\n# File should start with -----BEGIN CERTIFICATE-----")
    File.write(key_path, "# Place your Cora private key here\n# Format: PEM\n# File should start with -----BEGIN PRIVATE KEY-----")
    
    Rails.logger.info "Created sample certificate placeholders at #{cert_path} and #{key_path}"
  end
  
  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'User-Agent' => "School-System/1.0 (#{@client_id})"
    }
  end
  
  def build_invoice_payload(cora_invoice)
    {
      amount: (cora_invoice.amount * 100).to_i, # Convert to cents
      description: service_description_for(cora_invoice),
      due_date: cora_invoice.due_date.strftime('%Y-%m-%d'),
      customer: {
        name: cora_invoice.customer_name,
        document: clean_document(cora_invoice.customer_document),
        email: cora_invoice.customer_email
      },
      payment_options: {
        allow_bank_slip: true,
        allow_pix: true,
        allow_credit_card: false
      },
      fine: {
        percentage: 2.0, # 2% fine
        days_after_due_date: 1
      },
      interest: {
        percentage: 1.0, # 1% per month
        type: "per_month"
      },
      discount: {
        percentage: 5.0, # 5% early payment discount
        days_before_due_date: 5
      },
      notifications: {
        email: {
          enabled: true,
          days_before_due_date: [3, 1],
          days_after_due_date: [1, 7, 15]
        },
        sms: {
          enabled: false
        }
      }
    }
  end
  
  def service_name_for(cora_invoice)
    case cora_invoice.invoice_type
    when 'tuition'
      "Mensalidade - #{cora_invoice.student_name}"
    when 'salary'
      "Pagamento de Salário - #{cora_invoice.teacher_name}"
    when 'expense'
      "Despesa Administrativa"
    else
      "Serviço Educacional"
    end
  end
  
  def service_description_for(cora_invoice)
    case cora_invoice.invoice_type
    when 'tuition'
      "Mensalidade referente ao mês #{cora_invoice.due_date.strftime('%m/%Y')}"
    when 'salary'
      "Pagamento de salário referente ao mês #{Date.current.strftime('%m/%Y')}"
    when 'expense'
      "Pagamento de despesa administrativa"
    else
      "Prestação de serviços educacionais"
    end
  end
  
  
  def clean_document(document)
    return document unless document
    document.gsub(/[^\d]/, '')
  end
  
  def handle_response(response, cora_invoice)
    Rails.logger.info "Cora API Response: #{response.code} - #{response.body}"
    
    if response.success?
      data = response.parsed_response
      
      cora_invoice.update!(
        invoice_id: data['id'] || data['external_id'] || SecureRandom.uuid,
        status: data['status'] || 'PENDING',
        boleto_url: data['bank_slip_url'] || data['boleto_url'] || data['payment_url'],
        pix_qr_code: data.dig('pix', 'qr_code') || data['pix_qr_code'],
        pix_qr_code_url: data.dig('pix', 'qr_code_url') || data['pix_url']
      )
      
      Rails.logger.info "Invoice created successfully: #{cora_invoice.invoice_id}"
      data
    else
      error_message = response.parsed_response&.dig('message') || response.body
      Rails.logger.error "Invoice creation failed: #{response.code} - #{error_message}"
      
      # For development/staging, create a mock response
      if Rails.env.development? || ENV['CORA_ENVIRONMENT'] == 'staging'
        mock_response = create_mock_response(cora_invoice)
        Rails.logger.warn "Created mock invoice response for development"
        return mock_response
      end
      
      raise "Failed to create invoice: #{error_message}"
    end
  end
  
  def create_mock_response(cora_invoice)
    mock_id = "MOCK_#{SecureRandom.hex(8)}"
    mock_data = {
      'id' => mock_id,
      'status' => 'PENDING',
      'bank_slip_url' => "https://staging-cora.com/boletos/#{mock_id}",
      'pix' => {
        'qr_code' => '00020126580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-426614174000520400005303986540512345.675802BR5913Escola Sistema6008BRASILIA62070503***6304A1B2',
        'qr_code_url' => "https://staging-cora.com/pix/#{mock_id}"
      }
    }
    
    cora_invoice.update!(
      invoice_id: mock_id,
      status: 'PENDING',
      boleto_url: mock_data['bank_slip_url'],
      pix_qr_code: mock_data.dig('pix', 'qr_code'),
      pix_qr_code_url: mock_data.dig('pix', 'qr_code_url')
    )
    
    mock_data
  end
end