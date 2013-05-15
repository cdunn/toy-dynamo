require 'adapter'

module Toy
  module Dynamo
    module Adapter
      def read(key, options=nil)
        options ||= {}
        if @options[:model].dynamo_table.range_keys.present?
          raise ArgumentError, "Expected :range_value option" unless options[:range_value].present?
          result = @options[:model].dynamo_table.query(key, options.merge(
            :range => {
              "#{@options[:model].dynamo_table.range_keys.find{|k| k[:primary_range_key] }[:attribute_name]}".to_sym.eq => options[:range_value]
            }
          ))
        else
          result = @options[:model].dynamo_table.get_item(key, options)
        end

        attrs = (result[:member].empty? ? nil : Response.strip_attr_types(result[:member].first))
        attrs
      end

      def batch_read(keys, options=nil)
        options ||= {}
        @options[:model].dynamo_table.batch_get_item(keys, options)
      end

      def write(key, attributes, options=nil)
        options ||= {}
        @options[:model].dynamo_table.write(key, attributes, options)
      end

      def delete(key, options=nil)
        options ||= {}
        @options[:model].dynamo_table.delete(key, attributes, options)
      end

      def clear(options=nil)
        @options[:model].dynamo_table.delete
      end

      private

      def attributes_from_result(result)
        attrs = {}
        result.each_pair do |k,v|
          attrs[k] = v.values.first
        end
        attrs
      end

    end
  end
end

Adapter.define(:dynamo, Toy::Dynamo::Adapter)
