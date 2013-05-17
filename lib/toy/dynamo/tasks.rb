require 'rake'

namespace :ddb do
  desc 'Create a DynamoDB table'
  task :create => :environment do
    raise "expected usage: rake ddb:create CLASS=User" unless ENV['CLASS']
    options = {}
    options.merge!(:table_name => ENV['TABLE']) if ENV['TABLE']
    ENV['CLASS'].constantize.dynamo_table.create(options)
  end

  task :destroy => :environment do
    raise "expected usage: rake ddb:destroy CLASS=User" unless ENV['CLASS']
    options = {}
    options.merge!(:table_name => ENV['TABLE']) if ENV['TABLE']
    ENV['CLASS'].constantize.dynamo_table.delete(options)
  end
end
