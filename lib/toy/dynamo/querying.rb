module Toy
  module Dynamo
    module Querying
      extend ActiveSupport::Concern

      module ClassMethods

        # Read results up to the limit
        #   read_range("1", :range_value => "2", :limit => 10)
        # Loop results in given batch size until limit is hit or no more results
        #   read_range("1", :range_value => "2", :batch => 10, :limit => 1000)
        def read_range(hash_value, options={})
          raise ArgumentError, "no range_key specified for this table" if dynamo_table.range_keys.blank?
          aggregated_results = []

          results = dynamo_table.query(hash_value, options)
          response = Response.new(results)

          results[:member].each do |result|
            attrs = Response.strip_attr_types(result)
            aggregated_results << load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
          end

          if options[:batch]
            #!options[:limit] && 
            while response.more_results?
              results = dynamo_table.query(hash_value, options.merge(:exclusive_start_key => response.last_evaluated_key))
              response = Response.new(results)
              results[:member].each do |result|
                attrs = Response.strip_attr_types(result)
                aggregated_results << load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
              end
            end
          end

          aggregated_results
        end

        def count_range(hash_value, options={})
          raise ArgumentError, "no range_key specified for this table" if dynamo_table.range_keys.blank?
          results = dynamo_table.query(hash_value, options.merge(:select => :count))
          Response.new(results).count
        end

        def read_multiple(keys, options=nil)
          results_map = {}
          results = adapter.batch_read(keys, options)
          results[:responses][dynamo_table.table_schema[:table_name]].each do |result|
            attrs = Response.strip_attr_types(result)
            (results_map[attrs[dynamo_table.hash_key[:attribute_name]]] ||= {})[attrs[dynamo_table.range_keys.find{|rk| rk[:primary_range_key] }[:attribute_name]]] = load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
          end
          results_map
        end

      end # ClassMethods

    end
  end
end
