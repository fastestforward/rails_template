require 'open-uri'

def rails_version
  ::Rails::VERSION::STRING
end

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

def replace_module(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  gsub_file file, /^(module\s+.*?$).*^(end)/m, "\\1\n#{data}\n\\2" 
end

def replace_describe(file, data = nil, &block)
  replace_in_file(file, /^(describe\s+.*?$).*^(end)/m, "\\1\n#{data}\\2", &block)
end

def replace_in_file(file, regex, data = nil, &block)
  data = block.call if !data && block_given?
  gsub_file file, regex, data 
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

def add_to_top_of_module(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  match_count = 0
  gsub_file file, /^(module\s+.*)/ do |match|
    match_count += 1
    if match_count == 1 
      "#{match}\n#{data}\n"
    else
      match
    end
  end
  raise "Did not add_to_top_of_module: #{file.inspect}" if match_count.zero?
end

def add_to_bottom_of_module(file, data = nil, &block)
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
  raise "Did not add_to_bottom_of_module: #{file.inspect}" if match_count.zero?
end

def add_to_top_of_file(file, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  match_count = 0
  gsub_file file, /^/ do |match|
    match_count += 1
    if match_count == 1 
      "#{data}\n#{match}"
    else
      match
    end
  end
  raise "Did not add_to_top_of_file: #{file.inspect}" if match_count.zero?
end

def add_to_bottom_of_file(path, data = nil, &block)
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  File.open(path, 'a') do |file|
    file.write(data)
  end
end

def add_private_method_to_file(file, data = nil, &block) 
  data = block.call if !data && block_given?
  data = reindent(data, 2).chomp
  match_count = 0
  gsub_file file, /^\s+?(private\s+.*)/ do |match|
    match_count += 1
    if match_count == 1 
      "#{data}\n#{match}"
    else
      match
    end
  end
  raise "Did not add_private_method_to_file: #{file.inspect}" if match_count.zero?  
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

def user_model_name
  @user_model_name
end

def user_model_name=(name)
  @user_model_name = name
end

git :init

git_commit_all 'Base Rails application.', :initial => true do
  run "rm README"
  run "echo '= #{application_name.camelize}' > README.rdoc"
  run "rm public/index.html"
  run "rm public/images/rails.png"

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
      task :reset => %w(db:drop db:create db:schema:load db:migrate app:populate)
      task :seed => %w(seed:users)

      namespace :seed do
        desc 'Create default user accounts'
        task :users => :environment do
          require 'spec/support/factories'
          $stdout.sync = true

          print "Inserting Users"
          users = [
            ['Elijah Miller',  'elijah.miller@gmail.com'             ,  true],
            ['Kris Chambers',  'kristopher.chambers@gmail.com'       ,  true],
            ['Chris Zelenak',  'netshade@gmail.com'                  ,  true],
            ['Matt Hassurder', 'matthew.hassfurder@gmail.com'        ,  true],
          ]
          users.each do |name, email, admin|
            user = Factory(:user, :admin => true, :name => name, :email => email, :admin => admin)
            user.update_attributes :persistence_token => Digest::MD5::hexdigest(email) * 4
            print "."
          end
          puts " done.\n"
        end
      end

      task :populate => :seed do
        
      end
    end
  }) 
end

git_commit_all 'Added rails-footnotes for helpful development tools.' do
  gem "rails-footnotes", :env => :development
end

git_commit_all 'Added railmail for development email inspection.' do
  plugin 'railmail', :git => 'git://github.com/jqr/railmail.git', :env => :development
  environment 'ActionMailer::Base.delivery_method = :railmail', :env => :development
  generate 'railmail_migration'
end

git_commit_all 'Added erubis to improve templating performance.' do
  gem "erubis"
end

git_commit_all 'Added rails_xss to escape strings by default.' do
  plugin 'rails_xss', :git => 'git://github.com/rails/rails_xss.git'
end

git_commit_all 'Added annotate to display database schema in model files.' do
  gem 'annotate', :env => :development
end

git_commit_all 'Added carrierwave for handling attachments.' do
  gem 'carrierwave'
  gem 'aws', :lib => 'aws/s3'
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
  file('spec/support/factories.rb', '')
end

git_commit_all 'Added remarkable to spec simple things simply.' do
  gem 'remarkable', :lib => 'remarkable', :env => :test
end

git_commit_all 'Added cucumber for acceptance testing.' do
  generate(:cucumber)
  
  in_root do
    File.open(File.join('config', 'environments', 'cucumber.rb')) do |file|
      file.each do |line|
        if line =~ /config\.gem/
          add_to_bottom_of_file('config/environments/test.rb', "\n#{line.strip}\n")
        end
      end
    end
  end

  file('features/support/additional_env_requires.rb', reindent(%Q{
    require 'email_spec/cucumber'
    require "spec/mocks"

    Dir["#{'#{RAILS_ROOT}'}/spec/support/**/*.rb"].each {|f| require f}

    ActionMailer::Base.default_url_options[:host] = 'example.com'

    Before do
      Delayed::Job.delete_all
      $rspec_mocks ||= Spec::Mocks::Space.new
    end

    After do
      begin
        $rspec_mocks.verify_all
      ensure
        $rspec_mocks.reset_all
      end
    end
  }))
  
  
  file('features/step_definitions/step_helpers.rb', reindent(%Q{
    module StepHelpers

      def table_from_objects(objects, methods)
        table = [methods]
        table += objects.collect do |object|
          methods.collect { |m| object.send(m).to_s }
        end
        Cucumber::Ast::Table.new(table)
      end

      def textify_table_at(selector)
        table = table(tableish(selector, 'td,th'))
        table.headers.each do |header|
          table.map_column!(header) do |text| 
            text.to_s.strip.gsub(/<(.*?)>/, '')
          end
        end
        table
      end
    
    end

    World(StepHelpers)
  }))
  
  file('features/step_definitions/delayed_job_steps.rb', reindent(%Q{
    When 'the system processes jobs' do
      last_count = nil
      while Delayed::Job.count > 0 && Delayed::Job.count != last_count
        last_count = Delayed::Job.count
        Delayed::Worker.logger = nil
        worker = Delayed::Worker.new(:quiet => true)
        worker.work_off
      end
      Delayed::Job.all.should == []
    end
  }))
  
  file('features/step_definitions/debug_steps.rb', reindent(%Q{
    Then /^(I )?open IRB$/i do |optional|
      require 'irb'
      original_argv = ARGV
      ARGV.replace([])
      IRB.start
      ARGV.replace(original_argv)
    end

    Then /^(I )?save and open the page$/ do
      save_and_open_page
    end
  }))
  
  file('features/step_definitions/abstract_steps.rb', reindent(%Q{
    When /^there are ([0-9]+) (.+)$/ do |num, pluralized_class_name|
      klass = pluralized_class_name.classify.constantize
      1.upto(num) do |i|
        klass.create!(Factory.attributes_for(pluralized_class_name.singularize.to_sym))
      end
    end
  }))
  
  replace_in_file('features/support/env.rb', /(ENV\["RAILS_ENV"\] \|\|\= )"cucumber"/, "\\1\"test\"")
  
  quiet_run 'rm config/environments/cucumber.rb'
end

git_commit_all 'Added email_spec for email testing.' do
  # TODO use gem again when the delayed job warnings are fixed.
  # gem 'email_spec', :env => :test
  plugin('email_spec', :git => 'git://github.com/fastestforward/email-spec.git')
  generate :email_spec

  # Remove full rails/sinatra projects that interfere with jump to file.
  quiet_run 'rm -r vendor/plugins/email-spec/examples'

  replace_in_file('features/step_definitions/email_steps.rb', /(module EmailHelpers)(.*?)(end{1,})/m, reindent(%Q{
  \\1

    def current_email_address
      @current_user.email
    \\3
  }))
end

git_commit_all 'Added noisy_attr_accessible to warn on invalid mass assignment.' do
  file 'config/initializers/noisy_attr_accessible.rb', reindent(%q{
    ActiveRecord::Base.class_eval do
      def log_protected_attribute_removal(*attributes)
        raise "Can't mass-assign these protected attributes: #{attributes.to_sentence}"
      end
    end
  })
end

git_commit_all 'Added authlogic for application authentication.' do
  gem 'authlogic'
  self.user_model_name = 'user'

  route("map.resource :#{user_model_name}_session")
  
  # FIXME: this is creating resource and resources routes.
  # FIXME: should clean up any unecessary actions/views
  generate 'rspec_controller', "#{user_model_name}_sessions new"

  generate(:session, "-f #{user_model_name}_session")  
  
  replace_class "app/controllers/#{user_model_name}_sessions_controller.rb", reindent(%Q{
    def new
      @#{user_model_name}_session = #{user_model_name.camelcase}Session.new
    end

    def create
      @#{user_model_name}_session = #{user_model_name.camelcase}Session.new(params[:#{user_model_name}_session])
      if @#{user_model_name}_session.save
        flash[:notice] = "Login successful!"
        redirect_back_or_default root_path
      else
        flash.now[:alert] = 'Unable to login.'
        render :action => :new
      end
    end

    def destroy
      if current_#{user_model_name}_session
        current_#{user_model_name}_session.destroy
        flash[:notice] = "Logout successful!"
      end
      
      redirect_to root_path
    end
  }, 2)    

  # FIXME: unique and not null on email
  generate('rspec_model', "#{user_model_name} email:string name:string crypted_password:string password_salt:string perishable_token:string single_access_token:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime current_login_at:datetime last_login_ip:string current_login_ip:string admin:boolean email_verified:boolean")
  generate('rspec_controller', user_model_name.pluralize)
  route("map.resources :#{user_model_name.pluralize}, :except => :index")

  add_to_top_of_class File.join('app', 'models', "#{user_model_name}.rb"), reindent(%Q{
    acts_as_authentic do |c|
      c.login_field = :email
      c.validate_login_field = true
      c.validates_length_of_password_confirmation_field_options = validates_length_of_password_confirmation_field_options.merge({
        :minimum => 4
      })
      c.require_password_confirmation = false
      c.disable_perishable_token_maintenance = true
    end    
  
    validates_presence_of :password, :if => :force_validate_password
  })
  
  replace_class "app/controllers/#{user_model_name.pluralize}_controller.rb", reindent(%Q{
    before_filter :require_#{user_model_name}, :except => [:new, :create, :show]
    before_filter :require_no_#{user_model_name}, :only => [:new, :create]
    before_filter :require_same_#{user_model_name}, :only => [:edit, :update]

    def new
      @#{user_model_name} = #{user_model_name.camelcase}.new
    end

    def create
      @#{user_model_name} = #{user_model_name.camelcase}.new(params[:#{user_model_name}])
      if @#{user_model_name}.save
        flash[:notice] = "Account registered!"
        redirect_back_or_default #{user_model_name}_path(@#{user_model_name})
      else
        render :action => :new
      end
    end

    def show
      @#{user_model_name} = #{user_model_name.camelize}.find(params[:id])
    end

    def edit
      @#{user_model_name} = current_#{user_model_name}
    end

    def update
      @#{user_model_name} = current_#{user_model_name}
      if @#{user_model_name}.update_attributes(params[:#{user_model_name}])
        flash[:notice] = "Account updated!"
        redirect_to #{user_model_name}_path(@#{user_model_name})
      else
        render :action => :edit
      end
    end
    
    private
    
    def require_same_#{user_model_name}
      # TODO
      # current_#{user_model_name} && current_#{user_model_name}.id == params[:id].to_i
    end
  }, 2)
  
  add_to_bottom_of_class File.join('app', 'controllers', 'application_controller.rb'), reindent("

    helper_method :current_#{user_model_name}_session, :current_#{user_model_name}

    private
  
    def current_#{user_model_name}_session
      return @current_#{user_model_name}_session if defined?(@current_#{user_model_name}_session)
      @current_#{user_model_name}_session = #{user_model_name.camelcase}Session.find
    end

    def current_#{user_model_name}
      return @current_#{user_model_name} if defined?(@current_#{user_model_name})
      @current_#{user_model_name} = current_#{user_model_name}_session && current_#{user_model_name}_session.#{user_model_name}
    end

    def require_#{user_model_name}
      unless current_#{user_model_name}
        store_location
        flash[:notice] = \"You must be logged in to access this page\"
        redirect_to new_#{user_model_name}_session_url
      end
    end

    def require_no_#{user_model_name}
      if current_#{user_model_name}
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

  file "app/views/#{user_model_name}_sessions/new.html.erb", reindent(%Q{
    <%= title 'Login' %>

    <% semantic_form_for(@#{user_model_name}_session, :url => #{user_model_name}_session_path) do |f| %>
      <%= f.inputs :email, :password %>
      <% f.buttons do %>
        <%= f.commit_button 'Login' %> 
        <li>
          <%= link_to 'Forgot Password?', new_password_reset_path %>
        </li>
      <% end %>
    <% end %>
  })
    
  add_to_bottom_of_class 'spec/spec_helper.rb', reindent(%Q{
    def login_as(#{user_model_name})
      controller.stub!(:current_#{user_model_name}).and_return(#{user_model_name})
    end
  })
  
  # TODO map.resources :users => map.resources :users, :except => :destroy
  
  replace_describe "spec/models/#{user_model_name}_spec.rb", "\n"
  
  replace_describe "spec/controllers/#{user_model_name.pluralize}_controller_spec.rb", "\n"

  file("app/views/#{user_model_name.pluralize}/_form.html.erb", reindent(%Q{
    <% if !defined?(commit_button_text) %>
      <% commit_button_text = 'Save' %>
    <% end %>

    <% semantic_form_for(@#{user_model_name}) do |f| %>
      <% f.inputs do %>
        <%= f.input :email %>
        <%= f.input :password, :label => @user.new_record? ? 'Password' : 'New Password' %>
      <% end %>
      <% f.buttons do %>
        <%= f.commit_button commit_button_text %>
      <% end %>
    <% end %>    
  }))
  
  file("app/views/#{user_model_name.pluralize}/new.html.erb", reindent(%Q{

    <%= title 'Signup' %>

    <%= render :partial => 'form', :locals => { :commit_button_text => 'Signup' } %>

  }))

  file("app/views/#{user_model_name.pluralize}/edit.html.erb", reindent(%Q{

    <%= title 'Update' %>

    <%= render :partial => 'form' %>
  }))

  file("app/views/#{user_model_name.pluralize}/show.html.erb", reindent(%Q{
    <p>
      <b>Email:</b>
      <%=h @#{user_model_name}.email %>
    </p><br />

    <%= link_to 'Edit', edit_#{user_model_name}_path(@#{user_model_name}) %>
  }))
  
  
  add_to_top_of_file('spec/support/factories.rb', reindent(%Q{
    Factory.sequence :email do |n|
      "person#{'#{n}'}@example.com" 
    end

    Factory.define :#{user_model_name} do |f|
      f.name { Faker::Name.name }
      f.email do |u|
        "#{'#{u.name.downcase.gsub(/\W/, \'\')}'}@example.com"
      end
      f.password "test"
    end
  }))
  
  add_to_bottom_of_module('features/step_definitions/step_helpers.rb', reindent(%Q{
  
    def find_#{user_model_name.pluralize}(hashes)
      hashes.collect do |hash|
        value = hash.delete("#{user_model_name}")
        if !value.blank?
          #{user_model_name} = #{user_model_name.camelcase}.find_or_create_by_name(value) do |u| 
            u.attributes = Factory.attributes_for(:#{user_model_name}).merge(:name => value) 
          end
          { :#{user_model_name} => #{user_model_name} }.reverse_merge(hash)
        else
          hash
        end
      end
    end

    def find_#{user_model_name}_ids(hashes)
      hashes.collect do |hash|
        value = hash.delete("#{user_model_name}")
        if !value.blank?
          #{user_model_name}_id = #{user_model_name.camelcase}.find_or_create_by_name(value) do |u| 
            u.attributes = Factory.attributes_for(:#{user_model_name}).merge(:name => value) 
          end.id
          { :#{user_model_name}_id => #{user_model_name}_id }.reverse_merge(hash)
        else
          hash
        end
      end
    end
  
  }))
  
  file("features/step_definitions/#{user_model_name}_steps.rb", reindent(%Q{
    Given /^I am signed up as "([^\\"]*)"$/ do |name|
      @current_#{user_model_name} = Factory(:#{user_model_name}, :name => name)
    end

    Given /^the following #{user_model_name.pluralize}:$/ do |table|
      table.hashes.each do |attrs|
        attrs = attrs.dup 
        Factory(:#{user_model_name}, attrs)
      end
    end

    Then /^I should see the following #{user_model_name.pluralize}:$/ do |expected_#{user_model_name.pluralize}_table|
      expected_#{user_model_name.pluralize}_table.diff!(textify_table_at('table tr'))
    end

    Given /^I am logged in as "(.*)"$/ do |name|
      Given %Q{I login as "#{'#{name}'}" with password "test"}
      response.body.should =~ /Login successful/
    end

    Given /^I login as "(.*)" with password "(.*)"$/ do |name, password|
      @current_#{user_model_name} = #{user_model_name.camelcase}.find_or_create_by_name(name) do |u|
        # Attrs might be protected
        attrs = Factory.attributes_for(:#{user_model_name}, :name => name, :password => password)
        u.attributes = attrs
        u.name = name
        u.password = password
      end
      visit new_#{user_model_name}_session_path
      fill_in('email', :with => @current_#{user_model_name}.email)
      fill_in('password', :with => password)
      click_button('Login')  
    end

    Given /^there is a #{user_model_name} named "([^\\"]*)"$/ do |name|
      #{user_model_name} = #{user_model_name.camelcase}.find_or_create_by_name(name) do |u|
        # Attrs might be protected
        attrs = Factory.attributes_for(:#{user_model_name}, :name => name)
        u.attributes = attrs
        u.name = name
        u.password = attrs[:password]
      end
      #{user_model_name}.valid?.should == true
    end

    Given /^I am logged in as an admin$/ do
      Given 'I am logged in as "MrAdmin"'
      @current_#{user_model_name}.reload
      @current_#{user_model_name}.admin = true
      @current_#{user_model_name}.save
    end

    Given /^I am an? anonymous #{user_model_name}$/ do
    end

    Given /^I am a logged in #{user_model_name}$/ do
      Given 'I am logged in as "Some#{user_model_name.camelcase}"'
    end
    
  }))
  
  file("features/manage_#{user_model_name.pluralize}.feature", reindent(%Q{
    Feature: #{user_model_name.titlecase}
      In order to keep information specific to himself
      a #{user_model_name}
      wants to signup and manage their personal information

      Scenario: A #{user_model_name} can signup
        Given I am on the home page
        When I follow "Signup"
        And I fill in "email" with "kris@example.com"
        And I fill in "password" with "test123"
        And I press "Signup"
        Then I should see "Account registered"

      Scenario: A #{user_model_name} can login with their email address
        Given I am signed up as "Kris"
        And I am on the home page
        When I follow "Login"
        And I fill in "email" with "kris@example.com"
        And I fill in "password" with "test"
        And I press "Login"
        Then I should see "Login successful"

      Scenario: A #{user_model_name} can login with their email address with the wrong case
        Given I am signed up as "Kris"
        And I am on the home page
        When I follow "Login"
        And I fill in "email" with "KRIS@example.com"
        And I fill in "password" with "test"
        And I press "Login"
        Then I should see "Login successful"

      Scenario: A #{user_model_name} can logout
        Given I am logged in as "Kris"
        When I follow "Logout"
        Then I should see "Logout successful"
 
  }))
end

git_commit_all "Adding the Notifier" do
  post_instruction("Update email templates and attributes: app/models/notifier.rb")

  generate('mailer', "notifier")

  environment "config.action_mailer.default_url_options = { :host => 'localhost:3000' }", :env => :development  
  
  add_to_top_of_class('app/controllers/application_controller.rb', reindent(%Q{
    before_filter :set_action_mailer_host
  }))
  
  add_to_bottom_of_class('app/controllers/application_controller.rb', reindent(%Q{
    def set_action_mailer_host
      ActionMailer::Base.default_url_options[:host] = request.host
    end
  }))

  replace_class("app/models/notifier.rb", reindent(%Q{
    def signup(#{user_model_name})
      subject       'Thanks for signing up'
      recipients    #{user_model_name}.email
      from          'notifier@example.com'
      sent_on       Time.now  
      body       
    end

    def password_reset_instructions(#{user_model_name})
      subject       "Password Reset Instructions"  
      from          "notifier@example.com"
      recipients    #{user_model_name}.email  
      sent_on       Time.now  
      body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)  
    end

    def email_verification(#{user_model_name})
      subject       'Verify email address'
      recipients    #{user_model_name}.email
      from          'notifier@example.com'
      sent_on       Time.now  
      body          :verification_url => email_verification_url(user.perishable_token)
      
    end
  }))

  file("app/views/notifier/password_reset_instructions.text.erb", reindent(%Q{

    A request to reset your password has been made.  
    If you did not make this request, simply ignore this email.  
    If you did make this request just click the link below:  
      <%= @edit_password_reset_url %>
    If the above URL does not work try copying and pasting it into your browser.  
    If you continue to have problem please feel free to contact us.

  }))

  file("app/views/notifier/password_reset_instructions.html.erb", reindent(%Q{
    <p>
      A request to reset your password has been made.  
      If you did not make this request, simply ignore this email.  
      If you did make this request just click the link below:  
      <br/><br/>
      <%= link_to 'Reset Password', @edit_password_reset_url %>
      </br/><br/>
      If the above URL does not work try copying and pasting it into your browser.  
      If you continue to have problem please feel free to contact us.
    </p>
  }))
  

  file("app/views/notifier/signup.text.erb", reindent(%Q{

    Thanks for signing up!

  }))

  file("app/views/notifier/signup.html.erb", reindent(%Q{
    <p>
      Thanks for signing up!
    </p>
  }))

  file("app/views/notifier/email_verification.text.erb", reindent(%Q{

    Verify email address!
    
    <%= @verification_url %>

  }))

  file("app/views/notifier/email_verification.html.erb", reindent(%Q{
    <p>
      Verify email address!
      <%= link_to @verification_url, @verification_url %>
    </p>
  }))

  
end

git_commit_all 'Adding password reset.' do
  generate('rspec_controller', 'password_resets')
  route('map.resources :password_resets, :except => :destroy')
  add_to_top_of_class('app/controllers/password_resets_controller.rb', reindent(%Q{
    skip_before_filter :require_#{user_model_name}
    before_filter :load_#{user_model_name}_from_perishable_token, :only => [:edit, :update]

    def new
      @user = #{user_model_name.camelcase}.new
    end

    def create
      @#{user_model_name} = #{user_model_name.camelcase}.find_by_email(params[:#{user_model_name}][:email])
      if @#{user_model_name}
        @#{user_model_name}.reset_password!
        flash[:notice] = "Instructions to reset your password have been emailed to you. Please check your email."
        redirect_to root_path
      else
        flash.now[:alert] = "No user was found with that email address"
        render :action => 'new'
      end
    end

    def update
      @#{user_model_name}.password = params[:#{user_model_name}][:password]  
      @#{user_model_name}.force_validate_password = true
      if @#{user_model_name}.save  
        flash[:notice] = "Password successfully updated"  
        redirect_to #{user_model_name}_path(@#{user_model_name})
      else  
        render :action => :edit
      end
    end

    private

    def load_user_from_perishable_token
      @#{user_model_name} = #{user_model_name.camelcase}.find_using_perishable_token(params[:id])  
      if params[:id].blank? || !@#{user_model_name}  
        flash[:alert] = %Q{
          We're sorry, but we could not locate your account. \
          If you are having issues try copying and pasting the URL \
          from your email into your browser or restarting the \  
          reset password process.
        }
        redirect_to root_url
      end
    end
    
  }))
  
  file('app/views/password_resets/new.html.erb', reindent(%Q{
    <%= title 'Reset Password' %>

    <% semantic_form_for(:#{user_model_name}, :url => password_resets_path) do |f| %>
      <%= f.inputs :email %>
      <% f.buttons do %>
        <%= f.commit_button 'Reset Password' %>
      <% end %>
    <% end %>
  }))

  file('app/views/password_resets/edit.html.erb', reindent(%Q{
    <%= title 'Change Password' %>

    <% semantic_form_for(@#{user_model_name}, :url => password_reset_path(:id => @#{user_model_name}.perishable_token)) do |f| %>
      <%= f.inputs :password %>
      <% f.buttons do %>
        <%= f.commit_button 'Change Password' %>
      <% end %>
    <% end %>    
  }))
  
  add_to_top_of_class("app/models/#{user_model_name}.rb", reindent(%Q{
    attr_accessor :force_validate_password
  
    def reset_password!
      reset_perishable_token!
      Notifier.deliver_password_reset_instructions(self)
    end
  }))
  
  add_to_bottom_of_file("features/step_definitions/#{user_model_name}_steps.rb", reindent(%Q{
    Given /^I request the edit password reset page with token "(.*)"/ do |token|
      visit "/password_resets/#{'#{token}'}/edit"
    end
  }))

  add_to_bottom_of_file("features/manage_#{user_model_name.pluralize}.feature", reindent(%Q{
    Scenario: A #{user_model_name} can restore their account after forgetting their password
      Given I am signed up as "Kris"
      And I am on the home page
      When I follow "Login"
      And no emails have been sent
      And I follow "Forgot password?"
      And I fill in "email" with "kris@example.com"
      And I press "Reset Password"
      Then I should see "Please check your email"
      And I should receive an email
      When I open the email
      Then I should see "Password Reset Instructions" in the email subject
      When I click the first link in the email
      And I fill in "password" with "newcrazypassword"
      And I press "Change Password"
      Then I should see "Password successfully updated"
      When I follow "Logout"
      And I login as "Kris" with password "newcrazypassword"
      Then I should see "Login successful"

    Scenario Outline: A #{user_model_name} should not see the change password page if the token is like "<token>"
      Given I request the edit password reset page with token "<token>"
      Then I should see "We're sorry"
      Examples:
        | token     |
        | not_valid |


    Scenario Outline: A #{user_model_name} can not restore their with an invalid password
      Given I am signed up as "Kris"
      And I am on the home page
      When I follow "Login"
      And no emails have been sent
      And I follow "Forgot password?"
      And I fill in "email" with "kris@example.com"
      And I press "Reset Password"
      Then I should see "Please check your email"
      And I should receive an email
      When I open the email
      Then I should see "Password Reset Instructions" in the email subject
      When I click the first link in the email
      And I fill in "password" with "<password>"
      And I press "Change Password"
      Then I should not see "Password successfully updated"
      Examples:
        | password  |
        |           |
        | tny       |
  }))
end

if yes?('Add image uploads?')
  git_commit_all "Add image uploads to #{user_model_name.pluralize}" do
    post_instruction('Configure Carrierwave: config/initializers/carrierwave.rb')
    post_instruction('Create the s3 buckets')
    generate('uploader', 'Image')
    generate('rspec_model', 'image imageable_id:integer imageable_type:string file:string')    
    generate('rspec_controller', 'images')
    route('map.resources :images')
    replace_class('app/uploaders/image_uploader.rb', reindent(%Q{

      include CarrierWave::RMagick
      
      version :thumb do
        process :resize_to_fill => [50,50]
      end

      version :avatar do
        process :resize_to_fill => [100,100]    
      end

      version :full do
        process :resize_to_fill => [700,700]
      end

      def store_dir
        "uploads/#{'#{model.class.to_s.underscore}'}/#{'#{mounted_as}'}/#{'#{model.id}'}"
      end

      def default_url
        "/images/fallback/" + [version_name, "default.png"].compact.join('_')
      end

      def extension_white_list
        %w(jpg jpeg gif png)
      end

    }))
    
    file('config/initializers/carrierwave.rb', reindent(%Q{
      CarrierWave.configure do |config|
        if Rails.env.test? || Rails.env.cucumber?
          config.storage = :file
          config.enable_processing = false
        else
          config.storage = :s3
          config.s3_access_key_id = 'xxx'
          config.s3_secret_access_key = 'xxx'
          config.s3_bucket = "#{application_name.dasherize}-#{'#{Rails.env.dasherize}'}"
        end
      end
    }))
    
    file('spec/uploaders/image_uploader_spec.rb', reindent(%Q{
      require 'spec_helper'
      require 'carrierwave/test/matchers'

      describe ImageUploader do

        before do
          ImageUploader.enable_processing = true
        end

        after do
          ImageUploader.enable_processing = false
        end

      end      
    }));
    
    replace_class('app/models/image.rb', reindent(%Q{
      
      mount_uploader :file, ImageUploader

      belongs_to :imageable, :polymorphic => true
      
      def file_path(style = :avatar)
        file.versions[style].try(:url)
      end
      
      # Required for heroku
      # def cache_dir
      #   "#{'#{RAILS_ROOT}'}/tmp/uploads"
      # end
    }))
    
    add_to_top_of_class('app/models/user.rb', %Q{

      has_many :images, :as => :imageable

      accepts_nested_attributes_for :images

    })
    
    replace_class('app/controllers/images_controller.rb', reindent(%{
      before_filter :require_user
      
      def index
        @images = scope.all
      end
      
      def show
        @image = scope.find(params[:id])
      end
      
      def new
        @image = scope.new
      end
      
      def create
        @image = scope.new(params[:image])
        if @image.save
          flash[:notice] = 'Image was successfully created'
          redirect_to @image
        else
          render :action => 'new'
        end
      end
      
      def edit
        @image = scope.find(params[:id])
      end
      
      def update
        @image = scope.find(params[:id])
        if @image.update_attributes(params[:image])
          flash[:notice] = 'Image was successfully updated'
          redirect_to @image
        else
          render :action => 'edit'
        end
      end
      
      def destroy
        @image = scope.find(params[:id])
        @image.destroy
        flash[:notice] = 'Image was succesfully removed'
        redirect_to images_path
      end
      
      private
      
      def scope
        current_#{user_model_name}.images
      end
    }))

    file('app/views/images/_form.html.erb', reindent(%Q{
      <% semantic_form_for(@image, :html => { :multipart => true }) do |f| %>
        <% f.inputs do %>
          <%= f.input :file, :as => :file %>
        <% end %>
        <% f.buttons do %>
          <%= f.commit_button 'Save' %>
        <% end %>
      <% end %>      
    }))

    file('app/views/images/new.html.erb', reindent(%Q{
      <%= title 'New Image' %>

      <%= render :partial => 'form' %>
    }))
    
    file('app/views/images/edit.html.erb', reindent(%Q{
      <%= title 'Edit Image' %>

      <%= render :partial => 'form' %>
    }))

    file('app/views/images/index.html.erb', reindent(%Q{
      <%= title 'Images' %>
      
      <%= link_to 'New', new_image_path %>
      
      <ul id="images">
      <% @images.each do |image| %>
        <li>
          <%= link_to image_tag(image.file_path), image_path(image) %>
        </li>
      <% end %>
    }))
    
    file('app/views/images/show.html.erb', reindent(%Q{
      <%= title Image %>

      <div>
        <%= image_tag(@image.file_path) %>
      </div>

      <div>
        <%= link_to 'Edit', edit_image_path(@image) %> |
        <%= link_to 'Delete', image_path(@image), :confirm => 'Are you sure?', :method => :delete %>      
      </div>
    }))
    
  end
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

git_commit_all 'Automatically loading extensions and ruby files in /lib.' do
  file 'config/initializers/require_libs.rb', reindent(%q{"
    Dir.glob(Rails.root.join('lib', 'extensions', '**', '*.rb')).each do |file|
      require file
    end

    Dir.glob(Rails.root.join('lib', '*.rb')).each do |file|
      require file
    end
  "})
end

git_commit_all 'Most recent schema.' do
  rake "db:migrate"
  rake "db:test:clone"
end

git_commit_all 'Most recent annotations.' do
  run 'annotate'
end

git_commit_all 'Added Google Analytics tracking.' do
  gem 'google_analytics'
  initializer 'google_analytics.rb' do
    "Rubaidh::GoogleAnalytics.tracker_id = 'fake_tracker_id'"
  end
  post_instruction 'Configure Google Analytics: config/initializer/google_analytics.rb'
end


git_commit_all 'Added formtastic for standard forms' do
  gem 'formtastic', :version => '>= 0.9.10'
  generate :formtastic
end

# git_commit_all 'Adding blueprint for default style' do
#   %w(grid.css grid.png ie.css print.css reset.css typography.css forms.css).each do |file|
#     run "curl http://github.com/joshuaclayton/blueprint-css/raw/master/blueprint/src/#{file} > public/stylesheets/#{file}"
#   end
# end

git_commit_all 'Basic application layout.' do
  file('public/images/content_bg.png', open('http://github.com/fastestforward/rails_template/raw/rails2/assets/images/content_bg.png').read)
  file('public/javascripts/underscore-min.js', open('http://github.com/documentcloud/underscore/raw/master/underscore-min.js').read)
  file('public/javascripts/jquery.min.js', open('http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js').read)
  file "app/views/layouts/application.html.erb", reindent(%q{
    <!DOCTYPE html>
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
        <%= javascript_include_tag 'jquery.min.js', 'underscore-min.js', 'application' %>    
        <%= yield :head %>
      </head>
      <body>
        <div id="bg">
          <% if current_user.try(:admin?) || Rails.env.development? %>
            <%= system_status %>
            <style type="text/css">
              #container {
                margin-top: 40px
              }
            </style>
          <% end %>
          <div id="header-bg"></div>
          <div id="body-bg"></div>
        </div>
        <div id="container">
          <div id="header">
            <h1><%= link_to h(site_title), '/' %></h1>
            <ul id="user_actions">
              <% if current_user %>
                <%= link_to 'Logout', user_session_path, :method => :delete %>
              <% else %> 
                <%= link_to 'Login', new_user_session_path %>
                <%= link_to 'Signup', new_user_path %>
              <% end %>
            </ul>
          </div>

          <%= flash_messages %>

          <div id="content">
            <%= yield %>
          </div>
        </div>
        <%= yield :foot %>
        <script type="text/javascript">
          jQuery(function() {
            <%= yield :ready %>
          })
        </script>
      </body>
    </html>

  })
  
  file "public/stylesheets/application.css", reindent(%Q{
    html {
      background: #fff;
    }
    body {
      font: 14px/100% Geneva, Helvetica, Arail;
      color: #444;
    }
    h1 {
      font-size: 300%;
      padding: 15px 0 5px 0;
    }
    h2 {
      font-size: 200%;
    }
    h1 a {
      color: inherit;
      text-decoration: inherit;
    }
    #bg {
      position: absolute;
      top: 0;
      z-index: 0;
      width: 100%
    }
    #header-bg {
      height: 100px;
      background: #2d2d2d;
    }
    #body-bg {
      border-top: 1px solid #1b5983;
      border-bottom: 1px solid #35536f;
      height: 200px;
      width: 100%;
      background: -moz-linear-gradient(90deg, #3e77ad, #184773); 
      background: -webkit-gradient(linear, left top, left bottom, from(#3e77ad), to(#184773)); 
    }
    #container {
      position: relative;
      width: 960px;
      margin: 0 auto;
    }
    #header {
      height: 100px;
      margin-bottom: 25px;
    }
    #header h1 {
      color: #ddd;
      padding-top: 50px;
    }
    #flash {
      margin-bottom: 25px;
    }
    #flash div {
      border: 1px solid #bbb;
    }
    #flash {
      margin-bottom: 25px;
    }
    #flash div {
      border: 1px solid #bbb;
      margin-bottom: 25px;
    }
    #flash div {
      border: 1px solid #bbb;
      -moz-border-radius: 10px;
      -webkit-border-radius: 10px;
      -moz-box-shadow: 0 0 5px #333;
      -webkit-box-shadow: 0 0 5px #333;
      margin-top: 15px;
      padding: 10px 25px;
      background: #fff;
      text-align: center;
    }
    #flash .alert {
      border-color: #a00;
      background: #f55;
    }    
    #flash .notice {
      border-color: #0a0;
      background: #5f5;
    }
    #content {
      padding: 40px;
      min-height: 500px;
      background: #fff;
      background: url(/images/content_bg.png) no-repeat -10px 0;
      margin-bottom: 30px;
    }
    #user_actions {
      padding: 5px 0;
      position: absolute;
      top: 0;
      right: 0;
      background: #ddd;
      -moz-border-radius: 0 0 5px 5px;
      -webkit-border-radius: 0 0 5px 5px;
    }
    #user_actions a {
      color: #666;
      text-decoration: none;
      font-size: 120%;
      font-weight: bold;
      padding: 5px 10px;
    }
    #user_actions a:hover {
      text-decoration: underline;
    }

    #system_status {
      font-size: 13px;
    }
    #system_status.development {
      background: #811;
    }

    #system_status.demo {
      background: #116;
    }

    #system_status.stage {
      background: #616;
    }

    #system_status, #system_status a {
      color: #aaa;
    }
    #system_status a {
      text-decoration: underline;
    }
    #system_status {
      background: #333;
      list-style-type: none;
      margin: 0;
      padding: 10px;
      overflow: auto;
      height: 20px;
    }
    #system_status li {
      float: right;
      padding: 0 10px;
    }
    #system_status .value {
      color: #ddd;
      font-weight: bold;
    }
    #system_status .overview {
      float: left;
    }

    form.formtastic {
      background: #f7f7f7;
      border-radius: 5px;
      -khtml-border-radius: 5px;
      -webkit-border-radius: 5px;
      -moz-border-radius: 5px;
      padding: 10px;
      margin-top: 20px;
    }
    form.formtastic input, form.formtastic textarea {
      color: 444;
      padding: 2px 2px 2px 6px;
      font-size: 16px;
      background: #fff;
      border: 1px solid #ccc;
      -webkit-border-radius: 3px;
      -moz-border-radius: 3px;
    }
    form.formtastic fieldset ol li.password input, form.formtastic fieldset ol li.string input {
      width: 300px;
      max-width: 300px;
      min-height: 25px;
    }
    body form.formtastic fieldset ol li.text textarea {
      width: 98%;
    }
    form.formtastic fieldset ol li {
      margin-bottom: 20px;
    }
    form.formtastic fieldset.buttons {
      padding: 0;
    }
    form.formtastic .buttons a {
      float: right;
      padding: 14px 0 0 14px;
    }
    form.formtastic .buttons input {
      font-size: 18px;
      margin-top: 5px;
      padding: 2px 5px;
      border: 1px solid #aaa;
      background: -moz-linear-gradient(90deg, #ccc, #fff);
      background: -webkit-gradient(linear, left top, left bottom, from(#fff), to(#ccc));
    }
    form.formtastic .buttons input:hover {
      border: 1px solid #1A4E76;
      color: #1368a9;
    }
    form.formtastic .buttons input:active {
      background: -moz-linear-gradient(90deg, #fff, #ccc);
      background: -wekkit-gradient(linear, left top, left bottom, from(#fff), to(#ccc));
    }
    form.formtastic fieldset ol li label {
      display: block;
      width: auto;
      font-size: 18px;
      padding-bottom: 7px;
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
  
  file "public/stylesheets/print.css", reindent(%Q{
    
  })
  
  slogans = "
    If you really want to know
    Keep it all here
    Intensify your Intensity
    SRSLY
  ".strip.split("\n")


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
        #{slogans.random_element.inspect}
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
      messages = "".html_safe

      [:alert, :notice].each do |type|
        if flash[type].present?
          messages << content_tag(:div, flash[type], :class => type)
        end
      end

      if messages.present?
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
        [proc { Delayed::Job.count },                                'job',            nil,               'jobs-count'],
        [proc { User.count },                                        'user',           nil,               'users-count'],
        [proc { User.active.count  },                                'active user',    nil,               'active-users-count'],
      ]

      if Rails.env.development?
        attributes.push([proc { RailmailDelivery.count },                           'email',          '/railmail',       'emails-count'])
      end

      attributes.each do |value, countable, url, value_class|
        value = 
          begin
            Timeout.timeout(0.3) { value.call } || 'X'
          rescue TimeoutError
            '?'
          rescue Exception
            '!'
          end

        contents = content_tag('span', number_with_delimiter(value), :class => "value #{value_class}") + " #{pluralize_without_number(value, countable)}"
        contents = link_to contents, url if url
        items << content_tag('li', contents)
      end

      content_tag('ul', items.to_s.html_safe, :id => 'system_status', :class => Rails.env)
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
  
  add_to_top_of_class 'app/models/user.rb', reindent(%Q{
    named_scope :active, lambda { {
      :conditions => ['last_request_at > ?', 15.minutes.ago],
      :order => 'last_request_at DESC'
    } }
  }, 2)
end

git_commit_all 'Verifying email addresses.' do
  add_to_top_of_class 'app/models/user.rb', reindent(%Q{
    after_create :deliver_email_verification_instructions
  })
  
  add_to_bottom_of_class 'app/models/user.rb', reindent(%Q{
    def email=(value)
      super(value.to_s.strip.downcase)
    end
    
    def deliver_email_verification_instructions
      reset_perishable_token!
      Notifier.deliver_email_verification(self)
    end
    
    def verify!
      self.email_verified = true
      save(false)
    end
  })
  
  generate 'rspec_controller', 'email_verifications'
  
  replace_class 'app/controllers/email_verifications_controller.rb', reindent(%Q{
    before_filter :load_user_using_perishable_token

    def show
      if @user
        @user.verify!
        flash[:notice] = "Thank you for verifying your account."
      else
        flash[:alert] = "Unable to verify your account."
      end
      redirect_to root_url
    end

    private

    def load_user_using_perishable_token
      @user = User.find_using_perishable_token(params[:id])
      flash[:notice] = "Unable to find your account." unless @user
    end
  })
  
  route 'map.resources :email_verifications'
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

if %w(2.3.6 2.3.7 2.3.8).include?(rails_version)
  git_commit_all 'Patch ActionController::Integration cookie handling' do
    file('config/initializers/action_controller_integration_cookie_handling_monkey_patch.rb', reindent(%Q{
      module ActionController::Integration
        class Session
          private
          def encode_cookies
            cookies.inject("") do |string, (name, value)|
              string << "#{'#{name.sub(/^\n/, "")}'}=#{'#{value}'}; "
            end
          end
        end
      end
    }, 0)) 
  end
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

puts "Seeding the application..."
rake 'app:seed'

show_post_instructions
