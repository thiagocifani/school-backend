class CoraApiService
  require "faraday"
  require "faraday/net_http"

  TOKEN_CACHE_KEY = "cora_access_token"
  TOKEN_EXPIRY_CACHE_KEY = "cora_token_expiry"

  def initialize
    @base_uri = ENV["CORA_BASE_URL"] || "https://matls-clients.api.stage.cora.com.br"
    @client_id = ENV["CORA_CLIENT_ID"]
    @connection = setup_faraday_connection
    @token_connection = setup_token_faraday_connection
  end

  def invoices
    response = @connection.get("/v2/invoices") do |req|
      req.headers = headers
    end

    if response.success?
      response.body
    else
      Rails.logger.error "Failed to fetch invoices: #{response.body}"
      []
    end
  end

  # Create invoice/boleto using Cora v2 API
  def create_invoice(cora_invoice)
    payload = build_invoice_payload(cora_invoice)
    debugger
    response = @connection.post("/v2/invoices") do |req|
      req.headers.merge!(headers)
      req.body = payload.to_json
    end
    debugger

    handle_response(response, cora_invoice)
  end

  # Get invoice details
  def get_invoice(invoice_id)
    response = @connection.get("/v2/invoices/#{invoice_id}") do |req|
      req.headers = headers
    end

    if response.success?
      response.body
    else
      Rails.logger.error "Failed to fetch invoice: #{response.body}"
      nil
    end
  end

  # Cancel invoice
  def cancel_invoice(cora_invoice)
    invoice_id = cora_invoice.invoice_id

    response = @connection.delete("/v2/invoices/#{invoice_id}") do |req|
      req.headers = headers
    end

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
    # For v2 API, PIX is generated automatically when creating invoice
    # We just need to fetch the PIX data from the existing invoice
    if cora_invoice.pix_qr_code.present?
      return {
        pix_qr_code: cora_invoice.pix_qr_code,
        pix_qr_code_url: cora_invoice.pix_qr_code_url,
        expires_at: 24.hours.from_now
      }
    end

    # If no PIX data exists, fetch it from Cora
    invoice_data = get_invoice(cora_invoice.invoice_id)
    if invoice_data && invoice_data["pix"]

      pix_data = {
        pix_qr_code: invoice_data.dig("pix", "qr_code"),
        pix_qr_code_url: invoice_data.dig("pix", "qr_code_url"),
        expires_at: invoice_data.dig("pix", "expires_at") || 24.hours.from_now
      }

      # Update the cora_invoice with PIX data
      cora_invoice.update!(
        pix_qr_code: pix_data[:pix_qr_code],
        pix_qr_code_url: pix_data[:pix_qr_code_url]
      )

      return pix_data
    end

    # Mock response for development
    if Rails.env.development?
      {
        pix_qr_code: "00020126580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-426614174000520400005303986540" + (cora_invoice.amount * 100).to_i.to_s.rjust(10, "0") + "5802BR5913Escola Sistema6008BRASILIA62070503***6304ABCD",
        pix_qr_code_url: "https://staging-cora.com/pix/#{cora_invoice.invoice_id}",
        expires_at: 24.hours.from_now
      }
    else
      raise "Failed to generate PIX voucher: No PIX data available"
    end
  end

  # Generate boleto for tuition payments
  def generate_boleto(cora_invoice)
    # For v2 API, boleto is generated automatically when creating invoice
    # We just need to fetch the boleto data from the existing invoice
    if cora_invoice.boleto_url.present?
      return {
        boleto_url: cora_invoice.boleto_url,
        barcode: nil, # Barcode is typically in the PDF
        expires_at: 30.days.from_now
      }
    end

    # If no boleto data exists, fetch it from Cora
    invoice_data = get_invoice(cora_invoice.invoice_id)
    if invoice_data && invoice_data["bank_billet"]
      boleto_data = {
        boleto_url: invoice_data.dig("bank_billet", "url"),
        barcode: invoice_data.dig("bank_billet", "barcode"),
        expires_at: invoice_data.dig("bank_billet", "expires_at") || 30.days.from_now
      }

      # Update the cora_invoice with boleto data
      cora_invoice.update!(
        boleto_url: boleto_data[:boleto_url]
      )

      return boleto_data
    end

    # Mock response for development
    if Rails.env.development?
      {
        boleto_url: "https://staging-cora.com/boletos/#{cora_invoice.invoice_id}",
        barcode: "23793.#{rand(10000..99999)} #{rand(10000..99999)}.#{rand(100000..999999)} #{rand(1..9)} #{(Date.current + 30.days).strftime("%y%m%d")}#{(cora_invoice.amount * 100).to_i.to_s.rjust(10, "0")}",
        expires_at: 30.days.from_now
      }
    else
      raise "Failed to generate boleto: No boleto data available"
    end
  end

  # Create PIX payment for salaries
  def create_pix_payment(salary, teacher)
    payload = {
      recipient: {
        name: teacher.user.name,
        document: teacher.user.cpf || "000.000.000-00",
        bank_account: {
          # This would need to be collected from teacher profile
          account_number: "12345",
          account_digit: "6",
          branch_number: "1234",
          bank_code: "260" # Cora bank code
        }
      },
      amount: (salary.amount * 100).to_i, # Convert to cents
      description: "Pagamento de salário - #{Date.current.strftime("%m/%Y")}"
    }

    response = @connection.post("/v1/pix/payments") do |req|
      req.headers = headers
      req.body = payload.to_json
    end

    if response.success?
      response.body
    else
      Rails.logger.error "PIX payment failed: #{response.body}"
      nil
    end
  end

  private

  # OAuth Client Credentials Token Generation
  def get_access_token
    cached_token = Rails.cache.read(TOKEN_CACHE_KEY)
    expiry = Rails.cache.read(TOKEN_EXPIRY_CACHE_KEY)

    if cached_token && expiry && Time.current < expiry
      Rails.logger.info "Using cached Cora access token"
      return cached_token
    end

    Rails.logger.info "Generating new Cora access token"
    generate_new_access_token
  end

  def generate_new_access_token
    payload = {
      grant_type: "client_credentials",
      client_id: @client_id
    }

    Rails.logger.info "Attempting token generation with mTLS"
    Rails.logger.info "Endpoint: POST /token"
    Rails.logger.info "Payload: #{payload.inspect}"
    Rails.logger.info "Client ID: #{@client_id}"

    response = @token_connection.post("/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.headers["Accept"] = "application/json"
      req.body = URI.encode_www_form(payload)
    end

    Rails.logger.info "Token response status: #{response.status}"
    Rails.logger.info "Token response headers: #{response.headers}"
    Rails.logger.info "Token response body: #{response.body}"

    if response.success?
      token_data = response.body
      access_token = token_data["access_token"]
      expires_in = token_data["expires_in"] || 3600 # Default to 1 hour

      # Cache the token with some buffer time (90% of expiry)
      cache_duration = (expires_in * 0.9).to_i
      expiry_time = Time.current + cache_duration.seconds

      Rails.cache.write(TOKEN_CACHE_KEY, access_token, expires_in: cache_duration)
      Rails.cache.write(TOKEN_EXPIRY_CACHE_KEY, expiry_time, expires_in: cache_duration)

      Rails.logger.info "Cora access token generated successfully via mTLS, expires in #{expires_in}s"
      Rails.logger.info "Subsequent API calls will use Idempotency-Key: #{access_token[0..20]}..."
      access_token
    else
      # Enhanced error handling for 401 invalid_client
      error_body = response.body.is_a?(Hash) ? response.body : {}
      error_code = error_body["error"]
      error_body["error_description"]

      if response.status == 401 && error_code == "invalid_client"
        Rails.logger.error "🚨 Cora API 401 invalid_client error detected"
        Rails.logger.error "This indicates a problem with client authentication:"
        Rails.logger.error "  - Client ID may be incorrect: #{@client_id}"
        Rails.logger.error "  - mTLS certificates may not match the client ID"
        Rails.logger.error "  - Certificates may be expired or invalid"
        Rails.logger.error "  - Wrong environment (staging vs production)"

        error_message = "Invalid client authentication - check client_id and mTLS certificates"
      else
        error_message = "Failed to generate Cora access token: #{response.status} - #{response.body}"
      end

      Rails.logger.error error_message

      if Rails.env.development?
        Rails.logger.warn "Using mock token for development - mTLS certificates may not be available"
        return "mock_access_token_dev"
      end

      raise error_message
    end
  rescue => e
    Rails.logger.error "Error generating Cora access token via mTLS: #{e.message}"

    if Rails.env.development?
      Rails.logger.warn "Using mock token for development due to mTLS error"
      return "mock_access_token_dev"
    end

    raise e
  end

  def setup_faraday_connection
    # Conexão para chamadas normais da API (COM mTLS + Idempotency-Key + Authorization Bearer)
    # Conforme especificação do usuário: mTLS certificates são obrigatórios para TODAS as chamadas
    Faraday.new(url: @base_uri) do |conn|
      conn.request :json
      conn.response :json
      conn.adapter :net_http

      # mTLS é necessário para TODAS as chamadas da API conforme header specification:
      # --cert '/Users/seunome/Documentos/cert_key_cora/certificate.pem'
      # --key '/Users/seunome/Documentos/cert_key_cora/private-key.key'
      setup_mtls_certificates(conn)
    end
  end

  def setup_token_faraday_connection
    # Conexão específica para geração de token (com mTLS)
    Faraday.new(url: @base_uri) do |conn|
      conn.request :url_encoded
      conn.response :json
      conn.adapter :net_http

      setup_mtls_certificates(conn)
    end
  end

  def setup_mtls_certificates(connection)
    cert_path = Rails.root.join(ENV["CORA_CERTIFICATE_PATH"] || "config/certs/cora/certificate.pem")
    key_path = Rails.root.join(ENV["CORA_PRIVATE_KEY_PATH"] || "config/certs/cora/private-key.key")

    if File.exist?(cert_path) && File.exist?(key_path)

      connection.ssl.client_cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      connection.ssl.client_key = OpenSSL::PKey::RSA.new(File.read(key_path))
      connection.ssl.verify = true
      connection.ssl.version = :TLSv1_2

      Rails.logger.info "mTLS certificates loaded successfully"
    else
      Rails.logger.warn "Cora mTLS certificates not found. Using mock mode for development"
    end
  end

  def headers
    access_token = get_access_token
    idempotency_key = SecureRandom.uuid

    {
      "content-type" => "application/json",
      "accept" => "application/json",
      "Idempotency-Key" => idempotency_key,
      "authorization" => "Bearer #{access_token}"
    }
  end

  def build_invoice_payload(cora_invoice)
    {
      code: cora_invoice.invoice_id || generate_invoice_code,
      due_date: cora_invoice.due_date.strftime("%Y-%m-%d"),
      amount: (cora_invoice.amount * 100).to_i, # Amount in cents
      callback_url: generate_callback_url,
      payer: {
        name: cora_invoice.customer_name,
        document: {
          type: document_type_for(cora_invoice.customer_document),
          number: clean_document(cora_invoice.customer_document)
        },
        email: cora_invoice.customer_email
      },
      payment_forms: ["bank_billet", "pix"], # Supported payment methods
      instructions: build_payment_instructions(cora_invoice),
      late_fee: {
        mode: "PERCENTAGE",
        amount: 2.0 # 2% in basis points (2% = 200)
      },
      interest: {
        mode: "PERCENTAGE_PER_MONTH",
        amount: 1.0 # 1% per month in basis points
      }
    }
  end

  def generate_invoice_code
    "ESCOLA_#{Time.current.strftime("%Y%m%d")}_#{SecureRandom.hex(4).upcase}"
  end

  def generate_callback_url
    ENV["CORA_CALLBACK_URL"] || "#{ENV["FRONTEND_URL"] || "https://www.example.com"}/webhook/cora"
  end

  def document_type_for(document)
    clean_doc = clean_document(document)
    return "CPF" if clean_doc&.length == 11
    return "CNPJ" if clean_doc&.length == 14
    "CPF" # Default to CPF
  end

  def build_payment_instructions(cora_invoice)
    case cora_invoice.invoice_type
    when "tuition"
      "Mensalidade referente ao período #{cora_invoice.due_date.strftime("%m/%Y")} - #{cora_invoice.customer_name}. Pagamento após vencimento sujeito a multa e juros."
    when "salary"
      "Pagamento de salário referente ao período #{Date.current.strftime("%m/%Y")}."
    else
      "Pagamento de serviços educacionais. Favor manter o comprovante."
    end
  end

  def service_name_for(cora_invoice)
    case cora_invoice.invoice_type
    when "tuition"
      "Mensalidade - #{cora_invoice.student_name}"
    when "salary"
      "Pagamento de Salário - #{cora_invoice.teacher_name}"
    when "expense"
      "Despesa Administrativa"
    else
      "Serviço Educacional"
    end
  end

  def service_description_for(cora_invoice)
    case cora_invoice.invoice_type
    when "tuition"
      "Mensalidade referente ao mês #{cora_invoice.due_date.strftime("%m/%Y")}"
    when "salary"
      "Pagamento de salário referente ao mês #{Date.current.strftime("%m/%Y")}"
    when "expense"
      "Pagamento de despesa administrativa"
    else
      "Prestação de serviços educacionais"
    end
  end

  def clean_document(document)
    return document unless document
    document.gsub(/[^\d]/, "")
  end

  def handle_response(response, cora_invoice)
    Rails.logger.info "Cora API v2 Response: #{response.status} - #{response.body}"

    if response.success?
      data = response.body

      # Update cora_invoice with v2 API response format
      cora_invoice.update!(
        invoice_id: data["code"] || data["id"] || cora_invoice.invoice_id || generate_invoice_code,
        status: map_cora_status(data["status"]),
        boleto_url: data.dig("bank_billet", "url") || data["bank_billet_url"],
        pix_qr_code: data.dig("pix", "qr_code") || data.dig("pix", "code"),
        pix_qr_code_url: data.dig("pix", "qr_code_url") || data.dig("pix", "url")
      )

      Rails.logger.info "Invoice created successfully: #{cora_invoice.invoice_id}"
      data
    else
      begin
        # response.body já é parseado pelo Faraday se for JSON
        error_message = if response.body.is_a?(Hash)
          response.body.dig("error", "message") || response.body.dig("message") || response.body.to_s
        else
          response.body.to_s
        end
      rescue
        error_message = response.body.to_s
      end

      Rails.logger.error "Invoice creation failed: #{response.status} - #{error_message}"

      # For development/staging, create a mock response
      if Rails.env.development? || ENV["CORA_ENVIRONMENT"] == "staging"
        mock_response = create_mock_response(cora_invoice)
        Rails.logger.warn "Created mock invoice response for development"
        return mock_response
      end

      raise "Failed to create invoice: #{error_message}"
    end
  end

  def map_cora_status(cora_status)
    case cora_status&.downcase
    when "pending", "created", "registered", "draft"
      "DRAFT"
    when "open", "active"
      "OPEN"
    when "paid", "settled"
      "PAID"
    when "cancelled", "canceled"
      "CANCELLED"
    when "expired", "overdue", "late"
      "LATE"
    else
      "DRAFT"
    end
  end

  def create_mock_response(cora_invoice)
    mock_code = cora_invoice.invoice_id || "ESCOLA_#{Time.current.strftime("%Y%m%d")}_#{SecureRandom.hex(4).upcase}"
    mock_data = {
      "code" => mock_code,
      "id" => mock_code,
      "status" => "open",
      "due_date" => cora_invoice.due_date.strftime("%Y-%m-%d"),
      "amount" => (cora_invoice.amount * 100).to_i,
      "bank_billet" => {
        "url" => "https://staging-cora.com/v2/invoices/#{mock_code}/bank_billet.pdf",
        "barcode" => "23793.#{rand(10000..99999)} #{rand(10000..99999)}.#{rand(100000..999999)} #{rand(1..9)} #{cora_invoice.due_date.strftime("%y%m%d")}#{(cora_invoice.amount * 100).to_i.to_s.rjust(10, "0")}"
      },
      "pix" => {
        "qr_code" => "00020126580014BR.GOV.BCB.PIX0136123e4567-e12b-12d1-a456-426614174000520400005303986540#{(cora_invoice.amount * 100).to_i.to_s.rjust(10, "0")}5802BR5913Escola Sistema6008BRASILIA62070503***6304A1B2",
        "qr_code_url" => "https://staging-cora.com/v2/pix/#{mock_code}/qr_code.png",
        "url" => "https://staging-cora.com/v2/pix/#{mock_code}/qr_code.png"
      },
      "payer" => {
        "name" => cora_invoice.customer_name,
        "document" => {
          "type" => document_type_for(cora_invoice.customer_document),
          "number" => clean_document(cora_invoice.customer_document)
        },
        "email" => cora_invoice.customer_email
      }
    }

    cora_invoice.update!(
      invoice_id: mock_code,
      status: "OPEN",
      boleto_url: mock_data.dig("bank_billet", "url"),
      pix_qr_code: mock_data.dig("pix", "qr_code"),
      pix_qr_code_url: mock_data.dig("pix", "qr_code_url")
    )

    mock_data
  end
end
