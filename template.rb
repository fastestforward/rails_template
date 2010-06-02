def git_commit_all(message, options = '')
  unless options.is_a?(Hash) && options.delete(:initial)
    if git_dirty?
      puts "Aborting, we were about to start a commit for #{message.inspect} but there were already some files not checked in!"
      puts `git status`
      exit(1)
    end
  end
  
  yield if block_given?
  
  remove_crap

  git :add => "."
  git :commit => %Q{#{options} -a -m #{message.inspect}}
end

def git_dirty?
  `git status 2> /dev/null | tail -n1`.chomp != "nothing to commit (working directory clean)"
end

def model(name, contents)
  puts "generating model: #{name.camelcase}."
  file(File.join('app', 'models', "#{name}.rb"), %Q{class #{name.camelcase} < ActiveRecord::Base\n#{contents}\nend})
end

def reindent(data, base = 0)
  lines = data.split("\n")
  smallest_indentation = lines.collect { |l| l =~ /\S/ }.compact.min

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

def replace_describe(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  gsub_file file, /^(describe\s+.*?$).*^(end)/m, "\\1\n#{data}\n\\2" 
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

def quiet_run(cmd)
  run "#{cmd} 2> /dev/null", false
end

def remove_crap
  quiet_run 'rm -r spec/views/'
  quiet_run 'rm -r test/'
  quiet_run 'rm -r spec/fixtures/'
  Dir.glob(File.join('app', 'views', 'layouts', '*.html.erb')).each do |file|
    File.unlink(file) unless File.basename(file) == 'application.html.erb'
  end
end

git :init

git_commit_all 'Base Rails application.', :initial => true do
  run "rm README"
  run "echo '= #{application_name.camelize}' > README.rdoc"
  run "rm public/index.html"
  run "rm public/images/rails.png"
  run "rm public/favicon.ico"

  run "touch tmp/.gitignore log/.gitignore vendor/.gitignore public/images/.gitignore"
  
  file '.gitignore', reindent('
    .DS_Store
    log/*
    tmp/*
    config/database.yml
    db/*.sqlite*
    db/*.sql
  ')
  
  [nil, :development, :test, :production].each do |env|
    environment "\n", :env => env
  end
  
  uncomment_line File.join('app', 'controllers', 'application_controller.rb'), 'filter_parameter_logging :password'
end

git_commit_all 'Added factory_girl for easy object population.' do
  gem 'factory_girl'
end

git_commit_all 'Added faker for seed data generation.' do
  gem 'faker', :env => :development
  
  file 'lib/tasks/app.rake', reindent(%q{
    namespace :app do
      task :seed => :environment do

      end
      
      task :populate => :seed do
        
      end
    end
  }) 
end

git_commit_all 'Added rails-footnotes for easy development inspection and debugging.' do
  gem "rails-footnotes", :env => :development
end

git_commit_all 'Added railmail for development email inspection.' do
  plugin 'railmail', :git => 'git://github.com/jqr/railmail.git', :env => :development
  environment 'ActionMailer::Base.delivery_method = :railmail', :env => :development
  generate 'railmail_migration'
end

git_commit_all 'Added annotate to display database schema in model files.' do
  gem 'annotate', :env => :development
end

git_commit_all 'Added limerick_rake for handy rake tasks.' do
  plugin 'limerick_rake', :git => "git://github.com/thoughtbot/limerick_rake.git"
end

git_commit_all 'Added paperclip for handling attachments.' do
  gem 'paperclip'
  gem 'right_aws' # required by paperclip
end

git_commit_all 'Added will_paginate for pagination.' do
  gem 'will_paginate'
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

git_commit_all 'Removing default test directory in favor of rspec and cucumber.' do
  run "rm -rf test/"
end

git_commit_all 'Added rspec and rspec-rails.' do
  gem 'rspec', :lib => 'spec', :env => :test
  gem 'rspec-rails', :lib => 'spec/rails', :env => :test
  generate(:rspec)
end

git_commit_all 'Added remarkable to spec simple things simply.' do
  gem 'remarkable', :lib => 'remarkable', :env => :test
end

git_commit_all 'Added cucumber for acceptance testing.' do
  gem 'cucumber', :env => :test
  generate(:cucumber)
end

git_commit_all 'Added email_spec for email testing.' do
  # TODO:   require 'email_spec/cucumber' after the world require
  gem 'email_spec', :env => :test
  generate :email_spec
end

git_commit_all 'Added authlogic for application authentication.' do
  gem 'authlogic'
  model_name = 'user'

  route("map.resource :#{model_name}_session")
  
  # FIXME: this is creating resource and resources routes.
  # FIXME: should clean up any unecessary actions/views
  generate 'rspec_controller', "#{model_name}_sessions new"

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
  generate('rspec_scaffold', "#{model_name} email:string crypted_password:string password_salt:string perishable_token:string single_access_token:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string")
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

git_commit_all 'Added delayed_job for background tasks.' do
  gem 'delayed_job'
  generate 'delayed_job'
  
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
  generate :formtastic
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
        <title><%= strip_tags(page_and_site_title) %></title>
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
        <div id="container">
          <h1><%= link_to h(site_title), '/' %></h1>
          <ul id="user_actions">
            <% if current_user %>
              <%= link_to 'Logout', user_session_path, :method => :delete %>
            <% else %> 
              <%= link_to 'Login', new_user_session_path %>
              <%= link_to 'Register', new_user_path %>
            <% end %>
          </ul>

          <%= flash_messages %>

          <div id="content">
            <%= yield %>
          </div>
        </div>
        <%= yield :foot %>
      </body>
    </html>
  })
  
  file "public/stylesheets/application.css", reindent(%Q{
    html {
      background: #fafafa;
    }
    body {
      background: url(http://grawesome.heroku.com/ddd/fafafa/8x256.png) repeat-x;
    }

    #container {
      position: relative;
      width: 960px;
      margin: 0 auto;
    }
    h1 {
      font-size: 300%;
      padding: 15px 0 5px 0;
    }
    h1 a {
      color: inherit;
      text-decoration: inherit;
    }

    #content {
      border: 1px solid #bbb;
      -moz-border-radius: 10px;
      -webkit-border-radius: 10px;
      -moz-box-shadow: 0 0 5px #ccc;
      -webkit-box-shadow: 0 0 5px #ccc;
      padding: 20px 25px;
      min-height: 500px;
      background: #fff;
    }

    h2 {
      font-size: 200%;
    }

    #user_actions {
      padding: 5px 0;
      position: absolute;
      top: 0;
      right: 0;
      background: #ccc;
      -moz-border-radius: 0 0 5px 5px;
      -webkit-border-radius: 10px;
    }

    #user_actions a {
      padding: 5px 10px;
    }
  }, 0)
  
  file "public/stylesheets/formtastic_changes.css", reindent(%Q{
    form.formtastic fieldset ol li {
      display: block;
    }
    form.formtastic fieldset {
      display: block;
    }
    form.formtastic fieldset ol li label {
      float: none;
    }
    form.formtastic fieldset ol li.boolean label {
      padding-left: 0;
    }
    form.formtastic fieldset ol li.hidden {
      margin: 0;
      padding: 0;
    }
    form.formtastic li.hidden {
      display: none;
    }
    form.formtastic fieldset ol li p.inline-hints {
      color:#777777;
      margin:8px 0 0 20px;
    }  
    form.formtastic fieldset ol li p.inline-errors {
      margin:8px 0 0 20px;
    }
  }, 0)
  
  slogans = "
    If you really want to know
    Keep it all here
    Intensify your Intensity
    SRSLY
  ".strip.split("\n")


  # TODO: style flash messages
  file 'app/helpers/title_helper.rb', reindent(%Q{
    module TitleHelper
      def page_and_site_title
        if @page_title.present?
          [@page_title, site_title]
        else
          [site_title, site_slogan]
        end.compact.join(' // ')
      end

      def page_title
        @page_title
      end

      def meta_title
        if page_title.present?
          page_title
        else
          site_title
        end
      end

      def site_slogan
        #{slogans.rand.inspect}
      end

      def title(text = nil)
        @page_title = text
        content_tag('h2', text)
      end

      def site_title
        #{application_name.humanize.inspect}
      end
    end
  }, 0)
  
  add_to_bottom_of_class "app/helpers/application_helper.rb", reindent(%q{

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


    def pluralize_with_delimiter(count, singluar, plural = nil)
      number_with_delimiter(count) + ' ' + pluralize_without_number(count, singluar, plural)
    end

    def pluralize_without_number(count, singular, plural = nil)
      count == 1 ? singular : plural || singular.pluralize
    end

    def system_status
      items = [content_tag('li', h(Rails.env.upcase + ': ' + Time.zone.now.to_s(:long_ordinal)), :class => 'overview')]

      attributes = [
        # proc returning value                                       # pluralizable    # link             # value class
        [proc { Delayed::Job.count },                                'job',            delayed_jobs_path, 'jobs-count'],
        [proc { User.count },                                        'user',           admin_path,        'users-count'],
        [proc { User.active.count  },                                'active user',    nil,               'active-users-count'],
      ]


      items << content_tag('li', link_to("<span>#{session[:status_bar] != false ? 'Disable' : 'Enable'}</span>", toggle_status_bar_admin_path(:return_to => url_for)))

      attributes.each do |value, countable, url, value_class|
        value = 
          if session[:status_bar] != false
            begin
              Timeout.timeout(0.3) { value.call } || 'X'
            rescue Exception
              '?'
            end
          else
            'X'
          end

        contents = content_tag('span', number_with_delimiter(value), :class => "value #{value_class}") + " #{pluralize_without_number(value, countable)}"
        contents = link_to contents, url if url
        items << content_tag('li', contents)
      end

      content_tag('ul', items, :id => 'system_status', :class => Rails.env)
    end

    # Returns a link to url with the specified content, automatically adds 
    # rel="nofollow" and the external class to the link.
    def link_to_external(content, url, options = {})
      url = httpify_url(url)
      link_to content, url, options.merge(:rel => :nofollow, :class => "#{options[:class].to_s} external")
    end

    # Just like link_to_external, but uses the dehttpified url as the content.
    def link_to_external_url(url, options = {})
      link_to_external(h(dehttpify_url(url)), url, options)
    end

    # Adds http:// to a URL if missing.
    def httpify_url(url)
      if url.match(/^https?\:\/\//i)
        url
      else
        "http://#{url}"
      end
    end

    # Removes http:// from a URL if present.
    def dehttpify_url(url)
      if url.match(/^https?\:\/\//i)
        url.gsub(/^https?\:\/\//i, '')
      else
        url
      end
    end

    # Adds rel="nofollow" and auto_link class to all links by default.
    def auto_link(text, options = {}, &block)
      super(text, options.reverse_merge(:link => :all, :html => { :rel => :nofollow, :class => 'auto_link', :target => '_blank' }), &block)
    end
  })
end

git_commit_all 'Added static_pages for handling static pages and error messages.' do
  plugin 'static_pages', :git => 'git://github.com/jqr/static_pages.git'

  file "app/views/static_pages/index.html.erb", reindent(%Q{
    <p>Hello world.</p>
  })
  
  %w(about contact privacy 404 422 500).each do |page|
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
