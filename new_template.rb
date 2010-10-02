require 'helpers'

source_paths << File.join(File.dirname(File.expand_path(__FILE__)), 'overwrites')

def overwrite_file(file_name)
  remove_file "#{file_name}"
  copy_file "#{file_name}", "#{file_name}"
end

remove_file 'public/index.html'
remove_file 'public/images/rails.png'
remove_file 'README'
remove_dir 'doc'
add_file 'public/images/.gitkeep'

run 'cp config/database.yml config/database.yml.example'

overwrite_file('.gitignore')

inject_into_file 'config/application.rb', :after => 'config.filter_parameters += [:password]' do
  %Q(
    config.generators do |g|
      g.test_framework :rspec, :fixture => true, :view_specs => false
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.integration_tool :rspec
      g.stylesheets false
    end
  )
end

# TODO insert app name
add_file '.rvmrc' do
  %Q(
    rvm_install_on_use_flag=1
    rvm 1.9.2
    rvm_gemset_create_on_use_flag=1
    rvm gemset use APP_NAME
  )
end

gem 'jquery-rails'

# TODO run 'bundle install'

git :init
