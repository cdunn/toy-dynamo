module Toy
  module Dynamo
    module Schema
      extend ActiveSupport::Concern

      module ClassMethods

        KEY_TYPE = {
          :hash => "HASH",
          :range => "RANGE"
        }

        PROJECTION_TYPE = {
          :keys_only => "KEYS_ONLY",
          :all => "ALL",
          :include => "INCLUDE"
        }

        def dynamo_table(&block)
          if block
            @dynamo_table_config_block ||= block
          else
            @dynamo_table_config_block.call unless @dynamo_table_configged

            unless @dynamo_table
              @dynamo_table = Table.new(table_schema, self.adapter.client)
              validate_key_schema
            end
            @dynamo_table_configged = true
            @dynamo_table
          end
        end

        def table_schema
          schema = {
            :table_name => table_name,
            :provisioned_throughput => {
              :read_capacity_units => read_provision,
              :write_capacity_units => write_provision
            },
            :key_schema => key_schema,
            :attribute_definitions => attribute_definitions
          }
          schema.merge!(:local_secondary_indexes => local_secondary_indexes) unless local_secondary_indexes.blank?
          schema
        end

        def table_name(val=nil)
          if val
            raise(ArgumentError, "Invalid table name") unless val
            @dynamo_table_name = val
          else
            @dynamo_table_name ||= "#{Rails.application.class.parent_name.to_s.underscore.dasherize}-#{self.to_s.underscore.dasherize.pluralize.gsub(/[^a-zA-Z0-9_.-]/, '_')}-#{Rails.env}"
            @dynamo_table_name
          end
        end

        def read_provision(val=nil)
          if val
            raise(ArgumentError, "Invalid read provision") unless val.to_i >= 1
            @dynamo_read_provision = val.to_i
          else
            @dynamo_read_provision || 10
          end
        end

        def write_provision(val=nil)
          if val
            raise(ArgumentError, "Invalid write provision") unless val.to_i >= 1
            @dynamo_write_provision = val.to_i
          else
            @dynamo_write_provision || 10
          end
        end

        # TODO - need to add projections?
        def attribute_definitions
          # Keys for hash/range/secondary
          # S | N | B
          #{:attribute_name => , :attribute_type => }

          keys = []
          keys << hash_key[:attribute_name]
          keys << range_key[:attribute_name] if range_key
          local_secondary_indexes.each do |lsi|
            keys << lsi[:key_schema].select{|h| h[:key_type] == "RANGE"}.first[:attribute_name]
          end

          definitions = keys.uniq.collect do |k|
            attr = self.attributes[k.to_s]
            {
              :attribute_name => attr.name,
              :attribute_type => attribute_type_indicator(attr.type)
            }
          end
        end

        def attribute_type_indicator(type)
          if type == Array
            "S"
          elsif type == Boolean
            "S"
          elsif type == Date
            "N"
          elsif type == Float
            "N"
          elsif type == Hash
            "S"
          elsif type == Integer
            "N"
          elsif type == Object
            "S"
          elsif type == Set
            "S"
          elsif type == String
            "S"
          elsif type == Time
            "N"
          elsif type == SimpleUUID::UUID
            "S"
          else
            raise "unsupported attribute type #{type}"
          end
        end

        def key_schema
          raise(ArgumentError, 'hash_key was not set for this table') if @dynamo_hash_key.blank?
          schema = [hash_key]
          schema << range_key if range_key 
          schema
        end

        def hash_key(hash_key_key=nil)
          if hash_key_key
            hash_key_attribute = self.attributes[hash_key_key.to_s]
            raise(ArgumentError, "Could not find attribute definition for hash_key #{hash_key_key}") unless hash_key_attribute
            raise(ArgumentError, "Cannot use virtual attributes for hash_key") if hash_key_attribute.virtual?
            @dynamo_hash_key = {
              :attribute_name => hash_key_attribute.name,
              :key_type => KEY_TYPE[:hash]
            }
          else
            @dynamo_hash_key
          end
        end

        def range_key(range_key_key=nil)
          if range_key_key
            range_key_attribute = self.attributes[range_key_key.to_s]
            raise(ArgumentError, "Could not find attribute definition for range_key #{range_key_key}") unless range_key_attribute
            raise(ArgumentError, "Cannot use virtual attributes for range_key") if range_key_attribute.virtual?

            validates_presence_of range_key_attribute.name.to_sym

            @dynamo_range_key = {
              :attribute_name => range_key_attribute.name,
              :key_type => KEY_TYPE[:range]
            }
          else
            @dynamo_range_key
          end
        end

        def validate_key_schema
          if (@dynamo_table.schema_loaded_from_dynamo[:table][:key_schema] != table_schema[:key_schema])
            raise ArgumentError, "It appears your key schema (Hash Key/Range Key) have changed from the table definition. Rebuilding the table is necessary."
          end

          if (@dynamo_table.schema_loaded_from_dynamo[:table][:attribute_definitions] != table_schema[:attribute_definitions])
            raise ArgumentError, "It appears your attribute definition (types?) have changed from the table definition. Rebuilding the table is necessary."
          end
          
          if (@dynamo_table.schema_loaded_from_dynamo[:table][:local_secondary_indexes].collect {|i| i.delete_if{|k, v| [:index_size_bytes, :item_count].include?(k) }; i } != table_schema[:local_secondary_indexes])
            raise ArgumentError, "It appears your local secondary indexes have changed from the table definition. Rebuilding the table is necessary."
          end

          if @dynamo_table.schema_loaded_from_dynamo[:table][:provisioned_throughput][:read_capacity_units] != read_provision
            puts "read_capacity_units mismatch. Need to update table?"
          end

          if @dynamo_table.schema_loaded_from_dynamo[:table][:provisioned_throughput][:write_capacity_units] != write_provision
            puts "write_capacity_units mismatch. Need to update table?"
          end
        end

        def local_secondary_indexes
          @local_secondary_indexes ||= []
        end

        # @param [Symbol] index_attr the attribute to index secondary
        # @param [Hash] options
        # @option options [Symbol, Array<String>] :projection
        #   * `:all` 
        #   * `:keys_only` 
        #   * [:attributes to project]
        def local_secondary_index(range_key_attr, options={})
          options[:projection] ||= :keys_only
          local_secondary_index_hash = {
            :projection => {}
          }
          if options[:projection].is_a?(Array) && options[:projection].size > 0
            options[:projection].each do |non_key_attr|
              attr = self.attributes[non_key_attr.to_s]
              raise(ArgumentError, "Could not find attribute definition for projection on #{non_key_attr}") unless attr
              (local_secondary_index_hash[:projection][:non_key_attributes] ||= []) << attr.name
            end
            local_secondary_index_hash[:projection][:projection_type] = PROJECTION_TYPE[:include]
          else
            raise(ArgumentError, 'projection must be :all, :keys_only, Array (or attrs)') unless options[:projection] == :keys_only || options[:projection] == :all
            local_secondary_index_hash[:projection][:projection_type] = PROJECTION_TYPE[options[:projection]]
          end

          range_attr = self.attributes[range_key_attr.to_s]
          raise(ArgumentError, "Could not find attribute definition for local secondary index on #{range_key_attr}") unless range_attr
          local_secondary_index_hash[:index_name] = (options[:name] || "#{range_attr.name}_index".camelcase)

          hash_key_attr = self.attributes[hash_key[:attribute_name].to_s]
          raise(ArgumentError, "Could not find attribute definition for hash_key") unless hash_key_attr

          local_secondary_index_hash[:key_schema] = [
            {
              :attribute_name => hash_key_attr.name,
              :key_type => KEY_TYPE[:hash]
            },
            {
              :attribute_name => range_attr.name,
              :key_type => KEY_TYPE[:range]
            }
          ]
          (@local_secondary_indexes ||= []) << local_secondary_index_hash
        end

      end # ClassMethods

    end
  end
end
