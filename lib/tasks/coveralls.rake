begin
  require 'coveralls/rake/task'
  Coveralls::RakeTask.new
rescue LoadError
end
