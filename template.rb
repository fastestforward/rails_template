def git_commit_all(message, options = '')
  if block_given?
    yield
  end
  git :add => "."
  git :commit => %Q{#{options} -a -m #{message.inspect}}
end

def controller(name, contents)
  file(File.join('app', 'controllers', "#{name}_controller.rb"), %Q{class #{name.camelcase}Controller < ApplicationController::Base\n#{contents}\nend})
end

def model(name, contents)
  file(File.join('app', 'models', "#{name}.rb"), %Q{class #{name.camelcase} < ActiveRecord::Base\n#{contents}\nend})
end

def migration(*args)
  generate(:migration, args.join(' '))
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

git_commit_all 'Removing TestUnit.' do
  run "rm -rf test/"
end

git_commit_all 'Added development helpers: populator, faker, rails-footnotes, railmail2, annotate-models and limerick_rake.' do
  gem 'populator', :env => :development
  gem 'faker', :env => :development
  gem "josevalim-rails-footnotes",  :lib => "rails-footnotes", :source => "http://gems.github.com", :env => :development
  plugin 'railmail2', :git => 'git://github.com/theoooo/railmail2.git'
  environment 'ActionMailer::Base.delivery_method = :railmail', :env => :development
  gem 'annotate-models', :lib => 'annotate_models', :env => :development
  plugin 'limerick_rake', :git => "git://github.com/thoughtbot/limerick_rake.git"
end


git_commit_all 'Added general libraries: paperclip, will_paginate, newrelic_rpm and authlogic.' do
  gem 'thoughtbot-paperclip', :lib => 'paperclip', :source => 'http://gems.github.com'
  gem 'mislav-will_paginate', :lib => 'will_paginate', :source => 'http://gems.github.com'
  gem "newrelic_rpm" # TODO: get a default newrelic.yml
  gem 'authlogic'
end

# Start Authlogic generation

if yes?('Generate User and Session models and controllers for authlogic?')
  model_name = ask('User model name?[default: User]').downcase
  model_name = 'user' if model_name.blank?

  git_commit_all "Adding #{model_name}_session model and controller." do
  
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
  
  git_commit_all "Adding #{model_name} model and controller. " do

    model(model_name, "  acts_as_authentic")
    migration("create_#{model_name.pluralize} login:string crypted_password:string password_salt:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string")
    
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
  
  git_commit_all "Adding authlogic helper methods to application_controller" do
    gsub_file(File.join('app', 'controllers', 'application_controller.rb'), /end/, '\1' "
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
end

# END Authlogic generation

git_commit_all 'Adding production helpers: hoptoad_notifier and asset-version.' do
  # TODO: generate hoptoad api key
  plugin 'hoptoad_notifier', :git => "git://github.com/thoughtbot/hoptoad_notifier.git"
  plugin 'kristopher-asset-version', :git => 'git://github.com/kristopher/asset-version'
end

git_commit_all 'Capifying.' do
  capify!
end

# TODO: google analytics?

git_commit_all 'Adding concerns directory.' do
  file('app/concerns/.gitignore')
  environment 'config.load_paths += %W( #{RAILS_ROOT}/app/concerns )'
end

git_commit_all 'Recent schema.' do
  rake "db:migrate"
  rake "db:test:clone"
end

git_commit_all 'Adding rspec and rspec-rails.' do
  gem 'rspec', :lib => 'spec', :env => :test
  gem 'rspec-rails', :lib => 'spec/rails', :env => :test
  generate(:rspec)
end

git_commit_all 'Adding remarkable.' do
  gem 'carlosbrando-remarkable', :lib => 'remarkable', :source => "http://gems.github.com", :env => :test
end

git_commit_all 'Adding cucumber.' do
  gem 'cucumber', :env => :test
  generate(:cucumber)
end

git_commit_all 'Recent annotations.' do
  run 'annotate'
end

# TODO: push to github