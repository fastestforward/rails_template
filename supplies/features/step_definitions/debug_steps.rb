Then /^(I )?open IRB$/i do |optional|
  require 'irb'
  original_argv = ARGV
  ARGV.replace([])
  IRB.start
  ARGV.replace(original_argv)
end
