require 'active_record'
require 'logger'

ActiveRecord::Base.logger = Logger.new(STDERR)

ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database  => ":memory:"
)

# recursively requires all files in ./lib and down that end in .rb
Dir.glob('./lib/*').each do |folder|
  Dir.glob(folder +"/*.rb").each do |file|
    require file
  end
end

Dir.glob('./models/*').each do |folder|
  Dir.glob(folder +"/*.rb").each do |file|
    require file
  end
end
