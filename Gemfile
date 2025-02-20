source "https://rubygems.org"

ruby "3.4.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.0"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Active Record's Session Store extracted from Rails [https://github.com/rails/activerecord-session_store]
gem "activerecord-session_store"

# Make requests to BigQuery [https://cloud.google.com/ruby/docs/reference/google-cloud-bigquery/latest/index.html]
gem "google-cloud-bigquery"

# Rails integration for PRX authorization system [https://github.com/PRX/prx_auth-rails]
gem "prx_auth-rails", github: "prx/prx_auth-rails"

# CSV Reading and Writing [https://github.com/ruby/csv]
gem "csv"

# OpenStruct implementation [https://github.com/ruby/ostruct]
gem "ostruct"

# Better HTML for Rails [https://github.com/Shopify/better-html]
gem "better_html"

# The New Relic Ruby agent monitors your applications [https://docs.newrelic.com/docs/agents/ruby-agent]
gem "newrelic_rpm"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Shim to load environment variables from .env into ENV [https://github.com/bkeepers/dotenv]
  gem "dotenv"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Ruby's bikeshed-proof linter and formatter [https://github.com/standardrb/standard]
  gem "standard"

  # Lint your ERB or HTML files [https://github.com/Shopify/erb_lint]
  gem "erb_lint", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
