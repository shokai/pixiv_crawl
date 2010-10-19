#!/usr/bin/env ruby
require 'rubygems'
require 'mongo'
require 'bson'
require 'yaml'
require File.dirname(__FILE__)+'/lib/Pixiv'

begin
  @conf = YAML::load open(File.dirname(__FILE__) + '/config.yaml')
rescue
  puts 'config.yaml load error'
  exit 1
end

@datadir = File.dirname(__FILE__)+'/data'
@mongo = Mongo::Connection.new(@conf['mongo_host'], @conf['mongo_port'])
@db = @mongo[@conf['mongo_dbname']]
