begin
  require 'irb/completion'
rescue LoadError
  puts "Missing irb/completion"
end

begin
  require 'wirble'
  Wirble.init
  Wirble.colorize
rescue LoadError
  puts "Missing wirble"
end

begin
  require 'hirb'
rescue LoadError
  puts "Missing hirb"
end

begin
  require 'awesome_print'
  AwesomePrint.irb!
rescue LoadError
  puts "Missing awesome_print"
end

begin
  require 'sinatra/advanced_routes'
  Sinatra::Application.define_singleton_method :log_routes do
    each_route do |route|
      puts "#{route.app.name}: #{route.verb} #{route.path}"
    end && nil
  end
  Sinatra::Application.define_singleton_method :verbose_log_routes do
    each_route do |route|
      puts "#{route.app.name}: #{route.verb} #{route.path} #{route.pattern}"
    end && nil
  end
rescue LoadError
  puts "Missing sinatra/advanced_routes"
end

if File.directory? 'lib'
  $: << 'lib'
end
