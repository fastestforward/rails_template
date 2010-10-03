TEMPLATE_ROOT = File.dirname(File.expand_path(__FILE__))
source_paths << File.join(TEMPLATE_ROOT)
APP_NAME = File.basename(destination_root)

# require "#{File.join(TEMPLATE_ROOT, 'helpers.rb')}"

## Set up rvm
run "rvm gemset create #{APP_NAME}"
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
remove_file 'public/images/rails.png'
remove_file 'public/favicon.ico'
add_file 'public/images/.gitkeep'

remove_file 'README'
remove_dir 'doc'
add_file 'README.rdoc' do
  %Q(=#{APP_NAME})
end

# NOTE keep reset scripts up to date
copy_file 'overwrites/application.html.erb', 'app/views/layouts/application.html.erb'

remove_file 'db/seeds.rb'
add_file 'db/.gitkeep'

run 'cp config/database.yml config/database.yml.example'
remove_file '.gitignore'
copy_file 'overwrites/.gitignore', '.gitignore'

copy_file 'overwrites/app.rake', 'lib/tasks/app.rake'

run 'cp config/environments/production.rb config/environments/staging.rb'

copy_file 'overwrites/time_formats.rb', 'config/initializers/time_formats.rb'

remove_file 'Gemfile'
copy_file 'overwrites/Gemfile', 'Gemfile'

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

## Set up jQuery
run 'rails g jquery:install --ui'

## Set up testing stack
inject_into_file 'config/application.rb', :after => 'g.stylesheets false' do
  %Q(
      g.test_framework :rspec, :fixture => true, :view_specs => false
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.integration_tool :rspec)
end

run 'rails g rspec:install'
remove_dir 'autotest'
run 'rails g email_spec'
run 'rails g cucumber:install --rspec --capybara'

copy_file 'overwrites/hoptoad.rb', 'config/initializers/hoptoad.rb'

copy_file 'overwrites/google_analytics.rb', 'config/initializers/google_analytics.rb'

git :add => '-A'
git :commit => "-m 'Testing stack.'"

## Configure devise and generate User model
# TODO
