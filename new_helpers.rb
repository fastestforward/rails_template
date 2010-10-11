def git_commit_all(message, options = '')
  unless options.is_a?(Hash) && options.delete(:initial)
    if git_dirty?
      puts "Aborting, we were about to start a commit for #{message.inspect} but there were already some files not checked in!"
      puts `git status`
      exit(1)
    end
  end
  
  yield if block_given?
  
  git :add => '-A'
  git :commit => "-m #{message.inspect}"
end

def git_dirty?
  `git status 2> /dev/null | tail -n1`.chomp != "nothing to commit (working directory clean)"
end

def supply_file(filename)
  if File.exists?(File.join(destination_root, filename))
    remove_file filename
  end
  copy_file File.join('supplies', filename), filename
end
