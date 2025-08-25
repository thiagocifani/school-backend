# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      # Allow local development
      origins "http://localhost:3000", "http://127.0.0.1:3000", "http://localhost:3002", "http://127.0.0.1:3002", "http://localhost:3003", "http://127.0.0.1:3003"
    else
      # Allow production and staging origins
      allowed_origins = [
        ENV['FRONTEND_URL'],
        'https://raizes-frontend-994c596b2d99.herokuapp.com',
        /https:\/\/.*\.herokuapp\.com/,
        /https:\/\/.*\.vercel\.app/,
        /https:\/\/.*\.netlify\.app/
      ].compact.flatten

      origins allowed_origins
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
