def git_commit_all(message, options = '')
  if block_given?
    yield
  end
  git :add => "."
  git :commit => %Q{#{options} -a -m #{message.inspect}}
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