module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: [:login]
      
      def login
        Rails.logger.info "Login params: #{params.inspect}"
        
        email = params[:email] || params.dig(:auth, :email)
        password = params[:password] || params.dig(:auth, :password)
        
        Rails.logger.info "Email: #{email}, Password present: #{!password.blank?}"
        
        user = User.find_by(email: email)
        Rails.logger.info "User found: #{user.present?}"
        
        if user&.valid_password?(password)
          Rails.logger.info "Password valid: true"
          token = encode_token({ user_id: user.id })
          render json: {
            user: user_data(user),
            token: token
          }
        else
          Rails.logger.info "Password valid: false"
          render json: { error: 'Email ou senha inválidos' }, status: :unauthorized
        end
      end
      
      def logout
        head :ok
      end
      
      def validate_token
        render json: { user: user_data(current_user) }
      end
      
      private
      
      def encode_token(payload)
        secret_key = Rails.application.credentials.secret_key_base || 
                     ENV['RAILS_MASTER_KEY'] || 
                     Rails.application.secret_key_base
        JWT.encode(payload, secret_key)
      end
      
      def user_data(user)
        {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          cpf: user.cpf,
          phone: user.phone
        }
      end
    end
  end
end