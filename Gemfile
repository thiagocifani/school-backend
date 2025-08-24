source "https://rubygems.org"

ruby "3.4.1"

gem "rails", "~> 8.0.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# API
gem "rack-cors"
gem "jbuilder"
gem "jsonapi-serializer"

# Authentication
gem "devise"
gem "devise-jwt"

# Authorization
gem "pundit"

# Background Jobs
gem "sidekiq"
gem "redis"

# File Upload
gem "image_processing", "~> 1.2"
gem "aws-sdk-s3", require: false

# PDF Generation
gem "prawn"
gem "prawn-table"

# Pagination
gem "kaminari"

# Monitoring
gem "sentry-ruby"
gem "sentry-rails"

# Payment Gateway
gem "httparty"
gem "money-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "dotenv-rails"
end

group :development do
  gem "web-console"
  gem "error_highlight", ">= 0.4.0", platforms: [:ruby]
  gem "annotate"
  gem "bullet"
  gem "letter_opener"
end
