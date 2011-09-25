require 'rubygems'

require File.expand_path(File.dirname(__FILE__)) + '/app'

log = File.new("log/sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

ENV['CONFIG']=ENV['HOME'] + '/.nicovideo/'

run Sinatra::Application

