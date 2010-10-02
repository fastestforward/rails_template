namespace :app do
  desc "Resets the application state"
  task :reset => %w(db:drop db:create db:migrate app:populate) do
    puts "Application state reset."
  end
  
  task :seed => :environment do
    
  end
  
  task :populate => :seed do
    
  end
end
