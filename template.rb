def git_commit_all(message, options = '')
  yield if block_given?
  git :add => "."
  git :commit => %Q{#{options} -a -m #{message.inspect}}
end

def model(name, contents)
  puts "generating model: #{name.camelcase}."
  file(File.join('app', 'models', "#{name}.rb"), %Q{class #{name.camelcase} < ActiveRecord::Base\n#{contents}\nend})
end

def reindent(data, base = 0)
  lines = data.split("\n")
  smallest_indentation = lines.collect { |l| l =~ /\w/ }.compact.min

  lines.each do |line|
    line.gsub!(/^\s{#{smallest_indentation}}/, ' ' * base)
  end
  lines.join("\n")
end

def replace_class(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  gsub_file file, /^(class\s+.*?$).*^(end)/m, "\\1\n#{data}\n\\2" 
end

def add_to_top_of_class(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  match_count = 0
  gsub_file file, /^(class\s+.*)/ do |match|
    match_count += 1
    if match_count == 1 
      "#{match}\n#{data}\n"
    else
      match
    end
  end
  raise "Did not add_to_top_of_class: #{file.inspect}" if match_count.zero?
end

def add_to_bottom_of_class(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  match_count = 0
  gsub_file file, /^(end)/ do |match|
    match_count += 1
    if match_count == 1 
      "#{data}\n#{match}"
    else
      match
    end
  end
  raise "Did not add_to_bottom_of_class: #{file.inspect}" if match_count.zero?
end

def uncomment_line(file, line)
  gsub_file file, /#\s*#{Regexp.escape(line)}/, line
end
  
def migration(*args)
  generate(:migration, args.join(' '))
end

def application_name
  unless @application_name
    in_root do
      @application_name = File.basename(Dir.pwd)
    end
  end
  
  @application_name
end

def post_instructions
  @post_instructions ||= []
end

def post_instruction(instruction)
  post_instructions << instruction
end

def show_post_instructions
  unless post_instructions.empty?
    puts "=" * 80
    puts "Remaining tasks: "
    post_instructions.each do |instruction|
      puts "  * #{instruction}"
    end
    puts "=" * 80
  end
end

def remove_view_specs
  run 'rm -r spec/views'
end

git :init

git_commit_all 'Base Rails application.' do
  run "rm README"
  run "echo '= #{application_name.camelize}' > README.rdoc"
  run "rm public/index.html"
  run "rm public/images/rails.png"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"

  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore public/images/.gitignore"
  
  file '.gitignore', reindent('
    .DS_Store
    log/*
    tmp/*
    config/database.yml
    db/*.sqlite*
  ')
  
  [nil, :development, :test, :production].each do |env|
    environment "\n", :env => env
  end
  
  uncomment_line File.join('app', 'controllers', 'application_controller.rb'), 'filter_parameter_logging :password'
end

git_commit_all 'Added populator and faker for seed data generation.' do
  gem 'populator', :env => :development
  gem 'faker', :env => :development
  
  # TODO: populate.rake and maybe some contents!
  # TODO: consider something that could validate!
end

git_commit_all 'Added rails-footnotes for easy development inspection and debugging.' do
  gem "josevalim-rails-footnotes",  :lib => "rails-footnotes", :source => "http://gems.github.com", :env => :development
end

# FIXME: not working properly as a gem, verify 
git_commit_all 'Added railmail for development email inspection.' do
  gem 'jqr-railmail', :lib => 'railmail', :source => 'git://github.com/jqr/railmail.git', :env => :development
  environment 'ActionMailer::Base.delivery_method = :railmail', :env => :development
end

git_commit_all 'Added annotate_models to display database schema in model files.' do
  gem 'annotate-models', :lib => 'annotate_models', :env => :development
end

git_commit_all 'Added limerick_rake for handy rake tasks.' do
  plugin 'limerick_rake', :git => "git://github.com/thoughtbot/limerick_rake.git"
end

git_commit_all 'Added paperclip for handling attachments.' do
  gem 'thoughtbot-paperclip', :lib => 'paperclip', :source => 'http://gems.github.com'
end

git_commit_all 'Added will_paginate for pagination.' do
  gem 'mislav-will_paginate', :lib => 'will_paginate', :source => 'http://gems.github.com'
end

git_commit_all 'Added newrelic_rpm for performance inspection in development and production.' do
  gem "newrelic_rpm"
  file 'config/newrelic.yml', ''
  
  post_instruction 'Install and configure Newrelic: config/newrelic.yml'
end

git_commit_all 'Setting sessions to expire after 2 weeks.' do
  initializer 'sessions.rb' do
    'ActionController::Base.session_options[:expire_after] = 2.weeks'
  end
end

git_commit_all 'Added authlogic for application authentication.' do
  gem 'authlogic'
  model_name = 'person'

  route("map.resource :#{model_name}_session")
  
  # FIXME: this is creating resource and resources routes.
  # FIXME: should clean up any unecessary actions/views
  generate 'rspec_scaffold', "#{model_name}_session"

  generate(:session, "-f #{model_name}_session")  
  
  replace_class "app/controllers/#{model_name}_sessions_controller.rb", reindent(%Q{
    def new
      @#{model_name}_session = #{model_name.camelcase}Session.new
    end

    def create
      @#{model_name}_session = #{model_name.camelcase}Session.new(params[:#{model_name}_session])
      if @#{model_name}_session.save
        flash[:notice] = "Login successful!"
        redirect_back_or_default root_path
      else
        render :action => :new
      end
    end

    def destroy
      if current_#{model_name}_session
        current_#{model_name}_session.destroy
        flash[:notice] = "Logout successful!"
      end
      redirect_back_or_default new_#{model_name}_session_url
    end
  }, 2)    

  # FIXME: default to email instead of login
  # unique and not null
  generate('rspec_scaffold', "#{model_name} login:string crypted_password:string password_salt:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string")
  add_to_top_of_class File.join('app', 'models', "#{model_name}.rb"), "acts_as_authentic"
  replace_class "app/controllers/#{model_name.pluralize}_controller.rb", reindent(%Q{
    def new
      @#{model_name} = #{model_name.camelcase}.new
    end

    def create
      @#{model_name} = #{model_name.camelcase}.new(params[:#{model_name}])
      if @#{model_name}.save
        flash[:notice] = "Account registered!"
        redirect_back_or_default #{model_name}_path(@#{model_name})
      else
        render :action => :new
      end
    end

    def show
      @#{model_name} = current_#{model_name}
    end

    def edit
      @#{model_name} = current_#{model_name}
    end

    def update
      @#{model_name} = current_#{model_name}
      if @#{model_name}.update_attributes(params[:#{model_name}])
        flash[:notice] = "Account updated!"
        redirect_to #{model_name}_path(@#{model_name})
      else
        render :action => :edit
      end
    end
  }, 2)
  
  # FIXME: current_user is WRONG, should be current_#{model}
  add_to_bottom_of_class File.join('app', 'controllers', 'application_controller.rb'), reindent("

    helper_method :current_user_session, :current_user

    private
  
    def current_#{model_name}_session
      return @current_#{model_name}_session if defined?(@current_#{model_name}_session)
      @current_#{model_name}_session = #{model_name.camelcase}Session.find
    end

    def current_#{model_name}
      return @current_#{model_name} if defined?(@current_#{model_name})
      @current_#{model_name} = current_#{model_name}_session && current_#{model_name}_session.#{model_name}
    end

    def require_#{model_name}
      unless current_#{model_name}
        store_location
        flash[:notice] = \"You must be logged in to access this page\"
        redirect_to new_#{model_name}_session_url
        return false
      end
    end

    def require_no_#{model_name}
      if current_#{model_name}
        store_location
        flash[:notice] = \"You must be logged out to access this page\"
        redirect_to root_path
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end  
  ", 2)
  
  # FIXME: kill any additional layouts
  remove_view_specs
end

git_commit_all 'Added hoptoad to catch production exceptions.' do
  initializer 'hoptoad.rb', reindent('
    HoptoadNotifier.configure do |config|
      # config.api_key = ''
    end
  ')

  plugin 'hoptoad_notifier', :git => "git://github.com/thoughtbot/hoptoad_notifier.git"
  add_to_top_of_class File.join('app', 'controllers', 'application_controller.rb'), 
    "include HoptoadNotifier::Catcher"

  post_instruction 'Configure Hoptoad: config/initializer/hoptoad.rb'
end

git_commit_all 'Added asset-version for cached asset expiry.' do
  plugin 'kristopher-asset-version', :git => 'git://github.com/kristopher/asset-version'
end

git_commit_all 'Basic capistrano setup.' do
  capify!
  post_instruction 'Configure Capistrano: config/deploy.rb'
end

git_commit_all 'Added concerns directory to store reusable modules.' do
  original_load_paths = '# config.load_paths += %W( #{RAILS_ROOT}/extras )'
  new_load_paths = 'config.load_paths += %W( #{RAILS_ROOT}/app/concerns )'
  gsub_file 'config/environment.rb', /#{Regexp.escape(original_load_paths)}/, new_load_paths
  file('app/concerns/.gitignore')
end

git_commit_all 'Most recent schema.' do
  rake "db:migrate"
  rake "db:test:clone"
end

git_commit_all 'Removing default test directory in favor of rspec and cucumber.' do
  run "rm -rf test/"
end

git_commit_all 'Added rspec and rspec-rails.' do
  gem 'rspec', :lib => 'spec', :env => :test
  gem 'rspec-rails', :lib => 'spec/rails', :env => :test
  generate(:rspec)
end

git_commit_all 'Added remarkable to spec simple things simply.' do
  gem 'carlosbrando-remarkable', :lib => 'remarkable', :source => "http://gems.github.com", :env => :test
end

git_commit_all 'Added cucumber for acceptance testing.' do
  gem 'cucumber', :env => :test
  generate(:cucumber)
end

git_commit_all 'Added factory_girl for test object creation' do
  gem 'thoughtbot-factory_girl', :lib => 'factory_girl', :source => 'http://gems.github.com', :env => :test
end

git_commit_all 'Most recent annotations.' do
  run 'annotate'
end

git_commit_all 'Added Google Analyitcs tracking.' do
  gem 'rubaidh-google_analytics', :lib => 'rubaidh/google_analytics', :source => 'http://gems.github.com'
  initializer 'google_analytics.rb' do
    "Rubaidh::GoogleAnalytics.tracker_id = 'fake_tracker_id'"
  end
  post_instruction 'Configure Google Analytics: config/initializer/google_analytics.rb'
end

git_commit_all 'Generated a StaticsController for static pages.' do
  # FIXME add route: map.statics ':action/:id', :controller => 'statics'
  generate 'rspec_controller', 'statics about contact privacy 404 500'
  remove_view_specs
end

git_commit_all 'Added a staging environment with identical contents to production.' do
  run 'cp config/environments/production.rb config/environments/staging.rb'
end

# Note: this only works if you're using jqr-github-gem!
run 'github create-from-local --private'

# TODO: basic app layout

# TODO: email notification

# TODO: email-spec: gem 'bmabey-email_spec', :lib => 'email_spec', :source => 'http://gems.github.com'

# TODO: time initializers
# 
# initializer 'time_formats.rb',
# %q{
#    ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.update({
#      # 4/5/9
#      :mdy => proc { |t| t.strftime('%m/%d/%y').gsub /(\b)0/, '\1' },
#      # Sunday, April 5, 2009
#      :diary => proc { |t| t.strftime('%A, %B %e, %Y').sub(/  /, ' ') },
#    })
# }


show_post_instructions
