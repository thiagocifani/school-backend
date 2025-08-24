web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -e production
release: bundle exec rails db:migrate