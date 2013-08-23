require 'rake'

namespace :ddb do
  desc 'Create a DynamoDB table'
  task :create => :environment do
    raise "expected usage: rake ddb:create CLASS=User" unless ENV['CLASS']
    options = {}
    options.merge!(:table_name => ENV['TABLE']) if ENV['TABLE']
    if ENV["CLASS"] == "all"
      Toy::Dynamo::Config.included_models.each do |klass|
        puts "Creating table for #{klass}..."
        begin
          klass.dynamo_table(:novalidate => true).create(options)
        rescue Exception => e
          puts "Could not create table! #{e.inspect}"
        end
      end
    else
      ENV['CLASS'].constantize.dynamo_table(:novalidate => true).create(options)
    end
  end

  desc 'Resize a DynamoDB table read/write provision'
  task :resize => :environment do
    raise "expected usage: rake ddb:resize CLASS=User" unless ENV['CLASS']
    options = {}
    options.merge!(:table_name => ENV['TABLE']) if ENV['TABLE']
    options.merge!(:read_capacity_units => ENV['READ'].to_i) if ENV['READ']
    options.merge!(:write_capacity_units => ENV['WRITE'].to_i) if ENV['WRITE']
    ENV['CLASS'].constantize.dynamo_table.resize(options)
  end

  desc 'Destroy a DynamoDB table'
  task :destroy => :environment do
    raise "expected usage: rake ddb:destroy CLASS=User" unless ENV['CLASS']
    options = {}
    options.merge!(:table_name => ENV['TABLE']) if ENV['TABLE']
    if ENV["CLASS"] == "all"
      Toy::Dynamo::Config.included_models.each do |klass|
        puts "Destroying table for #{klass}..."
        begin
          klass.dynamo_table(:novalidate => true).delete(options)
        rescue Exception => e
          puts "Could not create table! #{e.inspect}"
        end
      end
    else
      ENV['CLASS'].constantize.dynamo_table(:novalidate => true).delete(options)
    end
  end
end
