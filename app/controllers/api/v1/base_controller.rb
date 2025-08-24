module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      
      private
      
      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end
      
      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors.full_messages }, 
               status: :unprocessable_entity
      end
      
      def forbidden
        render json: { error: 'Não autorizado' }, status: :forbidden
      end
      
      def current_user
        @current_user ||= User.find(decoded_token['user_id']) if decoded_token
      end
      
      def authenticate_user!
        render json: { error: 'Token inválido' }, status: :unauthorized unless current_user
      end
      
      def decoded_token
        @decoded_token ||= begin
          header = request.headers['Authorization']
          return nil unless header
          
          token = header.split(' ').last
          secret_key = Rails.application.credentials.secret_key_base || 
                       ENV['RAILS_MASTER_KEY'] || 
                       Rails.application.secret_key_base
          JWT.decode(token, secret_key)[0]
        rescue JWT::DecodeError
          nil
        end
      end
    end
  end
end