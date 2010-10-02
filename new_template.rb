TEMPLATE_ROOT = File.dirname(File.expand_path(__FILE__))
source_paths << File.join(TEMPLATE_ROOT)
APP_NAME = File.basename(destination_root)

require "#{File.join(TEMPLATE_ROOT, 'helpers.rb')}"

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

remove_file 'db/seeds.rb'
add_file 'db/.gitkeep'

run 'cp config/database.yml config/database.yml.example'
remove_file '.gitignore'
copy_file 'overwrites/.gitignore', '.gitignore'

# NOTE keep rails version up to date
# TODO make app name look purdy
add_file '.rvmrc' do
  %Q(
    rvm_install_on_use_flag=1
    rvm 1.9.2
    rvm_gemset_create_on_use_flag=1
    rvm gemset use #{APP_NAME}
  )
end

uncomment_line File.join('app', 'controllers', 'application_controller.rb'), 'filter_parameter_logging :password'

copy_file 'overwrites/app.rake', 'lib/tasks/app.rake'

remove_file 'Gemfile'
copy_file 'overwrites/Gemfile', 'Gemfile'
# run 'bundle install'

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
# TODO download libraries

## Set up testing stack
inject_into_file 'config/application.rb', :after => 'g.stylesheets false' do
  %Q(
      g.test_framework :rspec, :fixture => true, :view_specs => false
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.integration_tool :rspec
  )
end

# TODO user generate command here?
# run 'rails g rspec:install'
# remove_dir 'autotest'

git :add => '-A'
git :commit => "-m 'Initial commit'"
