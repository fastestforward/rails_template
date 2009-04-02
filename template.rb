def git_commit_all(message, options = '')
  yield if block_given?
  git :add => "."
  git :commit => %Q{#{options} -a -m #{message.inspect}}
end

def controller(name, contents)
  puts "generating controller: #{name.camelcase}Controller."
  file(File.join('app', 'controllers', "#{name}_controller.rb"), %Q{class #{name.camelcase}Controller < ApplicationController::Base\n#{contents}\nend})
end

def model(name, contents)
  puts "generating model: #{name.camelcase}."
  file(File.join('app', 'models', "#{name}.rb"), %Q{class #{name.camelcase} < ActiveRecord::Base\n#{contents}\nend})
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

git :init

git_commit_all 'Base Rails application.' do
  run "echo > README"
  run "rm public/index.html"
  run "rm public/images/rails.png"
  run "rm public/favicon.ico"
  run "rm public/robots.txt"

  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
  file '.gitignore', %w(
    .DS_Store
    log/*
    tmp/**/*
    config/database.yml
    db/*.sqlite*
  ).join("\n")
end

git_commit_all 'Added populator and faker for seed data generation.' do
  gem 'populator', :env => :development
  gem 'faker', :env => :development
end

git_commit_all 'Added rails-footnotes for easy development inspection and debugging.' do
  gem "josevalim-rails-footnotes",  :lib => "rails-footnotes", :source => "http://gems.github.com", :env => :development
end

git_commit_all 'Added railmail2 for development email inspection.' do
  gem 'jqr-railmail', :lib => 'railmail', :source => 'git://github.com/jqr/railmail.git'
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
  gem "newrelic_rpm" # TODO: get a default newrelic.yml
  file 'config/newrelic.yml', 
%Q{
  # here are the settings that are common to all environments
  common: &default_settings
    # ============================== LICENSE KEY ===============================
    # You must specify the licence key associated with your New Relic account.
    # This key binds your Agent's data to your account in the New Relic RPM service.
    license_key: ''

    # Agent Enabled
    # Use this setting to force the agent to run or not run.
    # Default is 'auto' which means the agent will install and run only if a
    # valid dispatcher such as Mongrel is running.  This prevents it from running
    # with Rake or the console.  Set to false to completely turn the agent off
    # regardless of the other settings.  Valid values are true, false and auto.
    # agent_enabled: auto

    # Application Name
    # Set this to be the name of your application as you'd like it show up in RPM.
    # RPM will then auto-map instances of your application into a RPM "application"
    # on your home dashboard page. This setting does not prevent you from manually
    # defining applications.
    app_name: #{application_name}

    # the 'enabled' setting is used to turn on the NewRelic Agent.  When false,
    # your application is not instrumented and the Agent does not start up or
    # collect any data; it is a complete shut-off.
    #
    # when turned on, the agent collects performance data by inserting lightweight
    # tracers on key methods inside the rails framework and asynchronously aggregating
    # and reporting this performance data to the NewRelic RPM service at NewRelic.com.
    # below.
    enabled: false

    # The newrelic agent generates its own log file to keep its logging information
    # separate from that of your application.  Specify its log level here.
    log_level: info

    # The newrelic agent communicates with the RPM service via http by default.
    # If you want to communicate via https to increase security, then turn on
    # SSL by setting this value to true.  Note, this will result in increased
    # CPU overhead to perform the encryption involved in SSL communication, but this
    # work is done asynchronously to the threads that process your application code, so
    # it should not impact response times.
    ssl: false


    # Proxy settings for connecting to the RPM server.
    #
    # If a proxy is used, the host setting is required.  Other settings are optional.  Default
    # port is 8080.
    #
    # proxy_host: hostname
    # proxy_port: 8080
    # proxy_user:
    # proxy_pass:


    # Tells transaction tracer and error collector (when enabled) whether or not to capture HTTP params. 
    # When true, the RoR filter_parameter_logging mechanism is used so that sensitive parameters are not recorded
    capture_params: false


    # Transaction tracer captures deep information about slow
    # transactions and sends this to the RPM service once a minute. Included in the
    # transaction is the exact call sequence of the transactions including any SQL statements
    # issued.
    transaction_tracer:

      # Transaction tracer is enabled by default. Set this to false to turn it off. This feature
      # is only available at the Silver and above product levels.
      enabled: true


      # When transaction tracer is on, SQL statements can optionally be recorded. The recorder
      # has three modes, "off" which sends no SQL, "raw" which sends the SQL statement in its 
      # original form, and "obfuscated", which strips out numeric and string literals
      record_sql: obfuscated

      # Threshold in seconds for when to collect stack trace for a SQL call. In other words, 
      # when SQL statements exceed this threshold, then capture and send to RPM the current
      # stack trace. This is helpful for pinpointing where long SQL calls originate from  
      stack_trace_threshold: 0.500

    # Error collector captures information about uncaught exceptions and sends them to RPM for
    # viewing
    error_collector:

      # Error collector is enabled by default. Set this to false to turn it off. This feature
      # is only available at the Silver and above product levels
      enabled: true

      # Tells error collector whether or not to capture a source snippet around the place of the
      # error when errors are View related.
      capture_source: true    

      # To stop specific errors from reporting to RPM, set this property to comma separated 
      # values
      #
      #ignore_errors: ActionController::RoutingError, ...


  # override default settings based on your application's environment

  # NOTE if your application has other named environments, you should
  # provide newrelic conifguration settings for these enviromnents here.

  development:
    <<: *default_settings
    # turn off communication to RPM service in development mode.
    # NOTE: for initial evaluation purposes, you may want to temporarily turn
    # the agent on in development mode.
    enabled: false

    # When running in Developer Mode, the New Relic Agent will present 
    # performance information on the last 100 transactions you have 
    # executed since starting the mongrel.  to view this data, go to 
    # http://localhost:3000/newrelic
    developer: true

  test:
    <<: *default_settings
    # it almost never makes sense to turn on the agent when running unit, functional or
    # integration tests or the like.
    enabled: false

  # Turn on the agent in production for 24x7 monitoring.  NewRelic testing shows
  # an average performance impact of < 5 ms per transaction, you you can leave this on
  # all the time without incurring any user-visible performance degredation.
  production:
    <<: *default_settings
    enabled: true

  # many applications have a staging environment which behaves identically to production.
  # Support for that environment is provided here.  By default, the staging environment has
  # the agent turned on.
  staging:
    <<: *default_settings
    enabled: true
    app_name: #{application_name} (Staging)
}
end

git_commit_all 'Added authlogic for application authentication.' do
  gem 'authlogic'
end

git_commit_all 'Setting sessions to expire after 2 weeks.' do
  initializer 'sessions.rb' do
    'ActionController::Base.session_options[:expire_after] = 2.weeks'
  end
end

model_name = 'person' if model_name.blank?

git_commit_all "Added #{model_name}_session model and controller." do
  route("map.resource :#{model_name}_session")
  
  generate(:session, "#{model_name}_session")
    
  controller("#{model_name}_sessions", %Q{
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
    redirect_back_or_default new_user_session_url
  end
  })    
end
  
git_commit_all "Added #{model_name} model and controller. " do
  generate(:scaffold, "#{model_name} login:string crypted_password:string password_salt:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string")
  gsub_file(File.join('app', 'models', "#{model_name.camelcase}.rb"), /end/, " acts_as_authentic\nend\n")
  controller("#{model_name.pluralize}", %Q{
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
  })  
end
  
git_commit_all "Added authlogic helper methods to application_controller" do
  gsub_file(File.join('app', 'controllers', 'application_controller.rb'), /end/, "
  filter_parameter_logging :password, :password_confirmation
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
end")
end

git_commit_all 'Added hoptoad to catch production exceptions.' do
  # TODO: generate hoptoad api key, install catcher
  plugin 'hoptoad_notifier', :git => "git://github.com/thoughtbot/hoptoad_notifier.git"
end

git_commit_all 'Added asset-version for cached asset expiry.' do
  plugin 'kristopher-asset-version', :git => 'git://github.com/kristopher/asset-version'
end

git_commit_all 'Basic capistrano setup.' do
  capify!
end

git_commit_all 'Added concerns directory to store reusable modules.' do
  file('app/concerns/.gitignore')
  environment 'config.load_paths += %W( #{RAILS_ROOT}/app/concerns )'
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

git_commit_all 'Most recent annotations.' do
  run 'annotate'
end

# TODO: push to github

# TODO: basic app layout

# TODO: google analytics?
