TEMPLATE_ROOT = File.dirname(File.expand_path(__FILE__))
source_paths << File.join(TEMPLATE_ROOT)
APP_NAME = File.basename(destination_root)

def supply_file(filename)
  if File.exists?(File.join(destination_root, filename))
    remove_file filename
  end
  copy_file File.join('supplies', filename), filename
end

## Set up rvm
run "rvm gemset create '#{APP_NAME}'"
run "rvm 1.9.2@#{APP_NAME}"

# TODO make app name look purdy
# NOTE keep rails version up to date
add_file '.rvmrc' do
  %Q(
    rvm_install_on_use_flag=1
    rvm 1.9.2
    rvm_gemset_create_on_use_flag=1
    rvm gemset use #{APP_NAME}
  )
end

## Clean up files before performing initial commit
remove_file 'public/index.html'
remove_file 'public/favicon.ico'
remove_file 'public/images/rails.png'
supply_file 'public/images/content_bg.png'

remove_file 'README'
remove_dir 'doc'
add_file 'README.rdoc' do
  %Q(=#{APP_NAME})
end

# NOTE keep reset scripts up to date
supply_file 'app/views/layouts/application.html.erb'

supply_file 'app/helpers/application_helper.rb'
supply_file 'app/helpers/title_helper.rb'

supply_file 'public/javascripts/application.js'

supply_file 'public/stylesheets/application.css'
supply_file 'public/stylesheets/formtastic.css'
supply_file 'public/stylesheets/formtastic_changes.css'
supply_file 'public/stylesheets/print.css'

remove_file 'db/seeds.rb'
# add_file 'db/.gitkeep'
# TODO remove this later when migrations are added

run 'cp config/database.yml config/database.yml.example'
supply_file '.gitignore'

supply_file 'lib/tasks/app.rake'

run 'cp config/environments/production.rb config/environments/staging.rb'

# copy_file 'overwrites/time_formats.rb', 'config/initializers/time_formats.rb'

supply_file 'Gemfile'

run 'bundle install'

git :init
git :add => '-A'
git :commit => "-m 'Initial commit'"

## Configure generators
inject_into_file 'config/application.rb', :after => 'config.filter_parameters += [:password]' do
  %Q(
    config.generators do |g|
      g.stylesheets false
    end
  )
end

git :add => '-A'
git :commit => "-m 'Prevent generators from making stylesheets.'"

## Set up jQuery
run 'rails g jquery:install --ui'

git :add => '-A'
git :commit => "-m 'Set up jQuery.'"

## Set up testing stack
inject_into_file 'config/application.rb', :after => 'g.stylesheets false' do
  %Q(
      g.test_framework :rspec, :fixture => true, :view_specs => false
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.integration_tool :rspec)
end

run 'rails g rspec:install'
remove_dir 'autotest'

run 'rails g cucumber:install --rspec --capybara'

gsub_file 'features/support/env.rb', /Capybara.default_selector = :css/, 'Dir["#{Rails.root}/spec/support/**/*.rb"].each {|f| require f}'
run 'rails g email_spec:steps'

supply_file'features/step_definitions/debug_steps.rb'

supply_file 'config/initializers/hoptoad.rb'
supply_file 'config/initializers/google_analytics.rb'

git :add => '-A'
git :commit => "-m 'Testing stack.'"

## Configure devise and generate User model
# From http://github.com/fortuity/rails3-mongoid-devise/
run 'rails generate devise:install'
run 'rails generate devise:views'

gsub_file 'config/environments/development.rb', /# Don't care if the mailer can't send/, '### ActionMailer Config'
gsub_file 'config/environments/development.rb', /config.action_mailer.raise_delivery_errors = false/ do
<<-RUBY
config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  # A dummy setup for development - no deliveries, but logged
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default :charset => "utf-8"
RUBY
end
gsub_file 'config/environments/production.rb', /config.i18n.fallbacks = true/ do
<<-RUBY
config.i18n.fallbacks = true

  config.action_mailer.default_url_options = { :host => 'yourhost.com' }
  ### ActionMailer Config
  # Setup for production - deliveries, no errors raised
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default :charset => "utf-8"
RUBY
end

run 'rails generate devise User'

gsub_file 'app/models/user.rb', /end/ do
<<-RUBY
  validates_presence_of :email
  validates_uniqueness_of :email, :case_sensitive => false
end
RUBY
end

## Finish setting up user authentication section
supply_file 'config/locales/devise.en.yml'
supply_file 'app/controllers/users_controller.rb'
supply_file 'app/controllers/user_sessions_controller.rb'
supply_file 'app/views/user_sessions/new.html.erb'
supply_file 'app/views/users/edit.html.erb'
supply_file 'app/views/users/new.html.erb'

# Set up static pages
supply_file 'app/controllers/static_pages_controller.rb'
supply_file 'app/helpers/static_pages_helper.rb'
supply_file 'app/views/static_pages/index.html.erb'
supply_file 'spec/controllers/static_pages_controller_spec.rb'

# Update default devise routes (add root route while we're at it)
gsub_file 'config/routes.rb', /devise_for :users/ do
<<-RUBY

  root :to => 'static_pages#index'

  devise_for :users, :controllers => { :sessions => 'user_sessions', :registrations => 'users', } do
    get 'users/new', :to => 'users#new'
    delete 'users/sign_out', :to => 'user_sessions#destroy'
  end
RUBY
end

git :add => '-A'
git :commit => "-m 'User authentication system.'"
