require 'rubygems'
 
log = File.new("log/sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

ENV['CONFIG']='conf/'
 
require 'app'
run Sinatra::Application

