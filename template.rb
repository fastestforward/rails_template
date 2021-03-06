TEMPLATE_ROOT = File.dirname(__FILE__)
$: << TEMPLATE_ROOT

require 'helpers'

git :init

git_commit_all 'Base Rails application.', :initial => true do
  run "rm README"
  run "echo '= #{application_name.camelize}' > README.rdoc"
  run "rm public/index.html"
  run "rm public/images/rails.png"
  run "rm public/favicon.ico"

  append_file '.gitignore', reindent('
    .DS_Store
    config/database.yml
  ')
  
  [nil, :development, :test, :production].each do |env|
    environment "\n", :env => env
  end
  
  uncomment_line File.join('app', 'controllers', 'application_controller.rb'), 'filter_parameter_logging :password'
end

# git_commit_all 'Added factory_girl for easy object population.' do
#   gem 'factory_girl'
# end

git_commit_all 'Added faker for seed data generation.' do
  gem 'faker', :group => :development
  
  file 'lib/tasks/app.rake', reindent(%q{
    namespace :app do
      task :seed => :environment do

      end
      
      task :populate => :seed do
        
      end
    end
  }) 
end

# git_commit_all 'Added rails-footnotes for easy development inspection and debugging.' do
#   gem "rails-footnotes", :group => :development
# end

git_commit_all 'Added will_paginate for pagination.' do
  gem "will_paginate", ">= 3.0.pre2"
end

# git_commit_all 'Added railmail for development email inspection.' do
#   plugin 'railmail', :git => 'git://github.com/jqr/railmail.git', :group => :development
#   environment 'config.action_mailer.delivery_method = :railmail', :group => :development
#   generate 'railmail_migration'
# end

git_commit_all 'Added annotate to display database schema in model files.' do
  gem 'annotate', :group => :development
end

git_commit_all 'Added paperclip for handling attachments.' do
  gem 'paperclip'
  gem 'right_aws' # required by paperclip
end

# git_commit_all 'Added newrelic_rpm for performance inspection in development and production.' do
#   gem "newrelic_rpm"
#   file 'config/newrelic.yml', ''
#   
#   post_instruction 'Install and configure Newrelic: config/newrelic.yml'
# end

# git_commit_all 'Setting sessions to expire after 2 weeks.' do
#   initializer 'sessions.rb' do
#     'ActionController::Base.session_options[:expire_after] = 2.weeks'
#   end
# end

git_commit_all 'Removing default test directory in favor of rspec and cucumber.' do
  run "rm -rf test/"
end

git_commit_all 'Added rspec and rspec-rails.' do
  gem 'rspec-rails', :version => '>= 2.0.0.beta.19', :require => 'spec/rails', :group => :test
  generate(:rspec)
end

git_commit_all 'Added remarkable to spec simple things simply.' do
  gem 'remarkable', :require => 'remarkable', :group => :test
end

git_commit_all 'Added cucumber for acceptance testing.' do
  gem 'cucumber', :group => :test
  generate(:cucumber)
end

git_commit_all 'Added email_spec for email testing.' do
  # TODO:   require 'email_spec/cucumber' after the world require
  gem 'email_spec', :group => :test
  generate :email_spec
end

git_commit_all 'Added authlogic for application authentication.' do
  gem 'authlogic'
  model_name = 'user'

  route("resource :#{model_name}_session")
  
  # FIXME: this is creating resource and resources routes.
  # FIXME: should clean up any unecessary actions/views
  generate 'rspec:controller', "#{model_name}_sessions new"

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
      
      redirect_to root_path
    end
  }, 2)    

  # FIXME: unique and not null on email
  generate('rspec:scaffold', "#{model_name} email:string crypted_password:string password_salt:string perishable_token:string single_access_token:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string")
  add_to_top_of_class File.join('app', 'models', "#{model_name}.rb"), "acts_as_authentic"
  replace_class "app/controllers/#{model_name.pluralize}_controller.rb", reindent(%Q{
    before_filter :require_user, :except => [:new, :create, :show]
    before_filter :require_no_user, :only => [:new, :create]
    before_filter :require_same_user, :only => [:edit, :update]

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
      @#{model_name} = #{model_name.camelize}.find(params[:id])
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
    
    private
    
    def require_same_user
      # TODO
      # current_user && current_user.id == params[:id].to_i
    end
  }, 2)
  
  add_to_bottom_of_class File.join('app', 'controllers', 'application_controller.rb'), reindent("

    helper_method :current_#{model_name}_session, :current_#{model_name}

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
      end
    end

    def require_no_#{model_name}
      if current_#{model_name}
        store_location
        flash[:notice] = \"You must be logged out to access this page\"
        redirect_to root_path
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

  file 'app/views/user_sessions/new.html.erb', reindent(%Q{
    <%= title 'Login' %>

    <% semantic_form_for(@#{model_name}_session, :url => user_session_path) do |f| %>
      <%= f.inputs :email, :password %>
      <% f.buttons do %>
        <%= f.commit_button 'Login' %>
      <% end %>
    <% end %>
  })
  
  file 'app/views/users/new.html.erb', reindent(%Q{
    <%= title 'Register' %>

    <% semantic_form_for(@#{model_name}) do |f| %>
      <%= f.inputs :email, :password, :password_confirmation %>
      <% f.buttons do %>
        <%= f.commit_button 'Register' %>
      <% end %>
    <% end %>
  })
  
  add_to_bottom_of_class 'spec/spec_helper.rb', reindent(%Q{
    def login_as(user)
      controller.stub!(:current_user).and_return(user)
    end
  })
  
  # TODO map.resources :users => map.resources :users, :except => :destroy
  
  replace_describe 'spec/models/user_spec.rb', "\n"
  
  file 'spec/controllers/users_controller_spec.rb', reindent(%Q{
    require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

    describe UsersController do

      def mock_user(stubs={})
        @mock_user ||= mock_model(User, stubs)
      end

      describe "GET show" do
        it "assigns the requested user as @user" do
          User.should_receive(:find).with("37").and_return(mock_user)
          get :show, :id => "37"
          assigns[:user].should equal(mock_user)
        end
      end

      describe "GET new" do
        describe "while logged out" do
          it "assigns a new user as @user" do
            User.should_receive(:new).and_return(mock_user)
            get :new
            assigns[:user].should equal(mock_user)
          end
        end

        describe "while logged in" do
          before(:each) do
            login_as mock_user
          end

          it "should redirect to root" do
            get :new
            response.should redirect_to(root_path)
          end
        end
      end

      describe "GET edit" do
        describe "while logged out" do
          it "should redirect the user to login" do
            get :edit, :id => "37"
            response.should redirect_to(new_user_session_path)
          end
        end

        describe "while logged in" do
          before(:each) do
            login_as mock_user
          end

          it "assigns the current user as @user" do
            get :edit
            assigns[:user].should equal(mock_user)
          end
        end
      end

      describe "POST create" do
        describe "while logged out" do
          describe "with valid params" do
            it "assigns a newly created user as @user" do
              attribites = {
                "email" => 'test@example.com',
                "password" => 'testing',
                "password_confirmation" => 'testing',
              }
              User.should_receive(:new).with(attribites ).and_return(mock_user(:save => true))
              post :create, :user => attribites
              assigns[:user].should equal(mock_user)
            end

            it "redirects to the created user" do
              User.stub!(:new).and_return(mock_user(:save => true))
              post :create, :user => {}
              response.should redirect_to(user_url(mock_user))
            end
          end

          describe "with invalid params" do
            it "assigns a newly created but unsaved user as @user" do
              User.stub!(:new).with({'these' => 'params'}).and_return(mock_user(:save => false))
              post :create, :user => {:these => 'params'}
              assigns[:user].should equal(mock_user)
            end

            it "re-renders the 'new' template" do
              User.stub!(:new).and_return(mock_user(:save => false))
              post :create, :user => {}
              response.should render_template('new')
            end
          end
        end

        describe "while logged in" do
          before(:each) do
            login_as mock_user
          end

          it "should redirect to root" do
            post :create, :user => {}
            response.should redirect_to(root_path)
          end
        end
      end

      describe "PUT udpate" do
        describe "while logged out" do
          it "should redirect the user to login" do
            put :update, :id => "1"
            response.should redirect_to(new_user_session_path)
          end
        end

        describe "while logged in" do
          before(:each) do
            login_as(mock_user)
            mock_user.stub!(:update_attributes).and_return(true)
          end

          it "updates the current user" do
            mock_user.should_receive(:update_attributes).with({'email' => 'jerk@example.com'})
            put :update, :id => "37", :user => {:email => 'jerk@example.com'}
          end

          it "assigns the current user as @user" do
            put :update, :id => "1"
            assigns[:user].should equal(mock_user)
          end

          describe "with valid params" do
            before(:each) do
              mock_user.stub!(:update_attributes).and_return(true)
            end

            it "redirects to the user" do
              put :update, :id => "1"
              response.should redirect_to(user_url(mock_user))
            end
          end

          describe "with invalid params" do
            before(:each) do
              mock_user.stub!(:update_attributes).and_return(false)
            end

            it "re-renders the 'edit' template" do
              put :update, :id => "1"
              response.should render_template('edit')
            end
          end
        end
      end

    end
  })
end

git_commit_all 'Added hoptoad to catch production exceptions.' do
  initializer 'hoptoad.rb', reindent('
    HoptoadNotifier.configure do |config|
      # config.api_key = ''
    end
  ')

  gem 'hoptoad_notifier'

  post_instruction 'Configure Hoptoad: config/initializer/hoptoad.rb'
end

git_commit_all 'Added asset-version for cached asset expiry.' do
  plugin 'kristopher-asset-version', :git => 'git://github.com/kristopher/asset-version'
end

# git_commit_all 'Basic capistrano setup.' do
#   capify!
#   post_instruction 'Configure Capistrano: config/deploy.rb'
# end

git_commit_all 'Added delayed_job for background tasks' do
  gem 'delayed_job'

  file 'lib/tasks/delayed_job.rake', reindent(%q{
    begin
      require 'delayed/tasks'
    rescue LoadError
      STDERR.puts "Run `rake gems:install` to install delayed_job"
    end
  })
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

git_commit_all 'Most recent annotations.' do
  run 'annotate'
end

git_commit_all 'Added Google Analyitcs tracking.' do
  gem 'google_analytics'
  initializer 'google_analytics.rb' do
    "Rubaidh::GoogleAnalytics.tracker_id = 'fake_tracker_id'"
  end
  post_instruction 'Configure Google Analytics: config/initializer/google_analytics.rb'
end


git_commit_all 'Added formtastic for standard forms' do
  gem 'formtastic'
  generate :formtastic_stylesheets
end

# git_commit_all 'Adding blueprint for default style' do
#   %w(grid.css grid.png ie.css print.css reset.css typography.css forms.css).each do |file|
#     run "curl http://github.com/joshuaclayton/blueprint-css/raw/master/blueprint/src/#{file} > public/stylesheets/#{file}"
#   end
# end

git_commit_all 'Basic application layout.' do
  file "app/views/layouts/application.html.erb", reindent(%q{
    <DOCTYPE html>
    <html>
      <head>
        <title><%= strip_tags(page_title) %></title>
        <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.8.0r4/build/reset/reset-min.css">
        <link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.8.0r4/build/fonts/fonts-min.css">
        <!-- reset ie grid typography -->
        <%= stylesheet_link_tag %w(formtastic formtastic_changes application) %>
        <%= stylesheet_link_tag 'print', :media => 'print' %>
        <!--[if lt IE 8]>
          <%= stylesheet_link_tag 'ie' %>
        <![endif]-->
        <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
        <%= yield :head %>
      </head>
      <body>
        <% if current_user %>
          <%= link_to 'Logout', user_session_path, :method => :delete %>
        <% else %> 
          <%= link_to 'Login', new_user_session_path %>
          <%= link_to 'Register', new_user_path %>
        <% end %>

        <%= flash_messages %>

        <%= yield %>
        
        <%= yield :foot %>
      </body>
    </html>
  })
  
  # TODO: application stylesheet
  
  file "public/stylesheets/formtastic_changes.css", reindent(%Q{
    form.formtastic fieldset ol li {
      display: block;
    }
    form.formtastic fieldset {
      display: block;
    }
    form.formtastic fieldset ol li label {
      text-align: right;
    }
  }, 0)
  
  # TODO: style flash messages
  
  add_to_bottom_of_class "app/helpers/application_helper.rb", reindent(%Q{
    def page_title
      [@title, site_title].compact.join(' // ')
    end
    
    def site_title
      '#{application_name.titlecase}'
    end
    
    def title(text = nil)
      @title = text
      content_tag('h1', text)
    end
    
    def flash_messages
      types = [:error, :notice, :warning]
      if types.any? { |t| !flash[t].blank? }
        messages = types.collect do |type|
          unless flash[type].blank?
            content_tag(:div, flash[type], :class => type)
          end
        end.join
        
        content_tag(:div, messages, :id => 'flash')
      end
    end
  })
end

git_commit_all 'Added static_pages for handling static pages and error messages.' do
  plugin 'static_pages', :git => 'git://github.com/jqr/static_pages.git'
  
  %w(index about contact privacy 404 422 500).each do |page|
    file "app/views/static_pages/#{page}.html.erb", reindent(%Q{
      <%= title #{page.inspect} %>
    })
  end
end

git_commit_all 'Added a staging environment with identical contents to production.' do
  run 'cp config/environments/production.rb config/environments/staging.rb'
end

# TODO: email notification

# TODO: email validation

git_commit_all 'Adding some standard time formats' do
  initializer 'time_formats.rb', reindent(%q{
     ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.update({
       # 4/5/9
       :mdy => proc { |t| t.strftime('%m/%d/%y').gsub /(\b)0/, '\1' },
       # Sunday, April 5, 2009
       :diary => proc { |t| t.strftime('%A, %B %e, %Y').sub(/  /, ' ') },
       # 2010-03-23 04:03PM
       :db_meridian => '%Y-%m-%d %I:%M%p',
     })
  })
end

if yes?('Push to a private github repo?')
  run 'github create-from-local --private'
end

if yes?('Deploy to Heroku?')
  heroku_application_name = application_name.gsub(/[^A-Z0-9-]/i, '-')
  run "heroku create #{heroku_application_name}"
  git_commit_all 'Added heroku_san for easily deploying to Heroku' do
    plugin 'heroku_san', :git => 'git://github.com/fastestforward/heroku_san.git'
  end
  git_commit_all 'Added Heroku gem manifest.' do 
    rake 'heroku:gems'
  end
  run 'git push heroku master' 
  run 'heroku rake db:migrate' 
  run 'heroku open'
end

show_post_instructions

# TODO: forgotten password
