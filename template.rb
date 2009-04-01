def git_commit_all(message, options = '')
  git :add => "."
  git :commit => %Q{#{options} -m #{message.inspect}}
end

git :init

run "echo > README"
run "rm public/index.html"
run "rm public/images/rails.png"
run "rm public/favicon.ico"
run "rm public/robots.txt"

run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
file '.gitignore', <<-END
.DS_Store
log/*
tmp/**/*
config/database.yml
db/*.sqlite*
END

git_commit_all 'Base Rails application.'

run "rm -rf test/"
git_commit_all 'Removing TestUnit.'


gem 'populator', :env => :development
gem 'faker', :env => :development
gem "josevalim-rails-footnotes",  :lib => "rails-footnotes", :source => "http://gems.github.com", :env => :development
plugin 'railmail2', :git => 'git://github.com/theoooo/railmail2.git'
environment 'ActionMailer::Base.delivery_method = :railmail', :env => :development
gem 'annotate-models', :lib => 'annotate_models', :env => :development
plugin 'limerick_rake', :git => "git://github.com/thoughtbot/limerick_rake.git"

git :add => "."
git :commit => "-a -m 'Added development helpers: populator, faker, rails-footnotes, railmail2, annotate-models and limerick_rake.'"

gem 'thoughtbot-paperclip', :lib => 'paperclip', :source => 'http://gems.github.com'
gem 'mislav-will_paginate', :lib => 'will_paginate', :source => 'http://gems.github.com'
gem "newrelic_rpm" # TODO: get a default newrelic.yml
gem 'authlogic'

git :add => "."
git :commit => "-a -m 'Added general libraries: paperclip, will_paginate, newrelic_rpm and authlogic.'"


# TODO: generate hoptoad api key
plugin 'hoptoad_notifier', :git => "git://github.com/thoughtbot/hoptoad_notifier.git"
plugin 'kristopher-asset-version', :git => 'git://github.com/kristopher/asset-version'

git :add => "."
git :commit => "-a -m 'Adding production helpers: hoptoad_notifier and asset-version.'"


capify!
git_commit_all 'Capifying.'

# google analytics?

# TODO: concerns
# Rails.configuration.load_paths << File.join(RAILS_ROOT, 'app', 'concerns')

rake "db:migrate"
rake "db:test:clone"

git :add => "."
git_commit_all 'Recent schema.'


gem 'rspec', :lib => 'spec', :env => :test
gem 'rspec-rails', :lib => 'spec/rails', :env => :test
generate(:rspec)

git :add => "."
git :commit => "-a -m 'Adding rspec and rspec-rails.'"

gem 'carlosbrando-remarkable', :lib => 'remarkable', :source => "http://gems.github.com", :env => :test
git_commit_all 'Adding remarkable.'

gem 'cucumber', :env => :test
generate(:cucumber)
git_commit_all 'Adding cucumber.'

run 'annotate'
git_commit_all 'Recent annotations.'

# TODO: push to github