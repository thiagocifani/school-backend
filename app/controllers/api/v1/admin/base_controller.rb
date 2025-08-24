module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        before_action :ensure_admin!
        
        private
        
        def ensure_admin!
          render json: { error: 'Acesso negado. Somente administradores.' }, status: :forbidden unless current_user&.admin?
        end
      end
    end
  end
end