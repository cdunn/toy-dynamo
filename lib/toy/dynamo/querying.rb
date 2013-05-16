module Toy
  module Dynamo
    module Querying
      extend ActiveSupport::Concern

      # Failsafe
      MAX_BATCH_ITERATIONS = 100

      module ClassMethods

        # Read results up to the limit
        #   read_range("1", :range_value => "2", :limit => 10)
        # Loop results in given batch size until limit is hit or no more results
        #   read_range("1", :range_value => "2", :batch => 10, :limit => 1000)
        def read_range(hash_value, options={})
          raise ArgumentError, "no range_key specified for this table" if dynamo_table.range_keys.blank?
          aggregated_results = []

          if (batch_size = options.delete(:batch))
            max_results_limit = options[:limit]
            if options[:limit] && options[:limit] > batch_size
              options.merge!(:limit => batch_size)
            end
          end
          results = dynamo_table.query(hash_value, options)
          response = Response.new(results)

          results[:member].each do |result|
            attrs = Response.strip_attr_types(result)
            aggregated_results << load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
          end

          if batch_size
            results_returned = response.count
            batch_iteration = 0
            while response.more_results? && batch_iteration < MAX_BATCH_ITERATIONS
              if max_results_limit && (delta_results_limit = (max_results_limit-results_returned)) < batch_size
                break if delta_results_limit == 0
                options.merge!(:limit => delta_results_limit)
              else
                options.merge!(:limit => batch_size)
              end

              results = dynamo_table.query(hash_value, options.merge(:exclusive_start_key => response.last_evaluated_key))
              response = Response.new(results)
              results[:member].each do |result|
                attrs = Response.strip_attr_types(result)
                aggregated_results << load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
              end
              results_returned += response.count
              batch_iteration += 1
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
            if dynamo_table.range_keys.present?
              (results_map[attrs[dynamo_table.hash_key[:attribute_name]]] ||= {})[attrs[dynamo_table.range_keys.find{|rk| rk[:primary_range_key] }[:attribute_name]]] = load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
            else
              results_map[attrs[dynamo_table.hash_key[:attribute_name]]] = load(attrs[dynamo_table.hash_key[:attribute_name]], attrs)
            end
          end
          results_map
        end

      end # ClassMethods

    end
  end
end
