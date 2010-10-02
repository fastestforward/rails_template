TEMPLATE_ROOT = File.dirname(File.expand_path(__FILE__))
source_paths << File.join(TEMPLATE_ROOT, 'overwrites')
APP_NAME = File.basename(destination_root)

require "#{File.join(TEMPLATE_ROOT, 'helpers.rb')}"

def overwrite_file(file_name)
  remove_file "#{file_name}"
  copy_file "#{file_name}", "#{file_name}"
end

## Clean up files before performing initial commit
remove_file 'public/index.html'
remove_file 'public/images/rails.png'
add_file 'public/images/.gitkeep'

remove_file 'README'
remove_dir 'doc'
add_file 'README.rdoc' do
  %Q(=#{APP_NAME})
end

remove_file 'db/seeds.rb'
add_file 'db/.gitkeep'

run 'cp config/database.yml config/database.yml.example'
overwrite_file('.gitignore')

# NOTE keep rails version up to date
add_file '.rvmrc' do
  %Q(
    rvm_install_on_use_flag=1
    rvm 1.9.2
    rvm_gemset_create_on_use_flag=1
    rvm gemset use #{APP_NAME}
  )
end

run 'bundle install'

git :init
git :add => '-A'
git :commit => "-m 'Initial commit'"

## Prevent generators from creating stylesheets
inject_into_file 'config/application.rb', :after => 'config.filter_parameters += [:password]' do
  %Q(
    config.generators do |g|
      g.stylesheets false
    end
  )
end

## Set up jQuery
gem 'jquery-rails'

## Set up testing stack
append_file 'Gemfile' do
%Q(
group :test, :development do
  gem 'capybara'
  gem 'cucumber-rails'
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'rspec-rails', '>= 2.0.0.beta.22'
  gem 'spork'
end
)
end

run 'bundle install'

inject_into_file 'config/application.rb', :after => 'g.stylesheets false' do
  %Q(
      g.test_framework :rspec, :fixture => true, :view_specs => false
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.integration_tool :rspec
  )
end

run 'rails g rspec:install'
