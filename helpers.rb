
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
  run "#{cmd} 2> /dev/null", :verbose => false
end

def remove_crap
  quiet_run 'rm -r spec/views/'
  quiet_run 'rm -r test/'
  quiet_run 'rm -r spec/fixtures/'
  Dir.glob(File.join('app', 'views', 'layouts', '*.html.erb')).each do |file|
    File.unlink(file) unless File.basename(file) == 'application.html.erb'
  end
end
