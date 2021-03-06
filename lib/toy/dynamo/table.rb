module Toy
  module Dynamo
    class Table

      attr_reader :table_schema, :client, :schema_loaded_from_dynamo, :hash_key, :range_keys

      RETURNED_CONSUMED_CAPACITY = {
        :none => "NONE",
        :total => "TOTAL"
      }

      TYPE_INDICATOR = {
        :b => "B",
        :n => "N",
        :s => "S",
        :ss => "SS",
        :ns => "NS"
      }

      QUERY_SELECT = {
        :all => "ALL_ATTRIBUTES",
        :projected => "ALL_PROJECTED_ATTRIBUTES",
        :count => "COUNT",
        :specific => "SPECIFIC_ATTRIBUTES"
      }

      COMPARISON_OPERATOR = {
        :eq => "EQ",
        :le => "LE",
        :lt => "LT",
        :ge => "GE",
        :gt => "GT",
        :begins_with => "BEGINS_WITH",
        :between => "BETWEEN",
        # Scan only
        :ne => "NE",
        :not_null => "NOT_NULL",
        :null => "NULL",
        :contains => "CONTAINS",
        :not_contains => "NOT_CONTAINS",
        :in => "IN"
      }

      COMPARISON_OPERATOR_SCAN_ONLY = [
        :ne, 
        :not_null,
        :null,
        :contains,
        :not_contains,
        :in
      ]

      def initialize(table_schema, client, options={})
        @table_schema = table_schema
        @client = client
        self.load_schema unless options[:novalidate]
      end

      def load_schema
        @schema_loaded_from_dynamo = self.describe

        @schema_loaded_from_dynamo[:table][:key_schema].each do |key|
          key_attr = @table_schema[:attribute_definitions].find{|h| h[:attribute_name] == key[:attribute_name]}
          next if key_attr.nil?
          key_schema_attr = {
            :attribute_name => key[:attribute_name],
            :attribute_type => key_attr[:attribute_type]
          }

          if key[:key_type] == "HASH"
            @hash_key = key_schema_attr
          else
            (@range_keys ||= []) << key_schema_attr.merge(:primary_range_key => true)
            @primary_range_key = key_schema_attr.merge(:primary_range_key => true)
          end
        end

        if @schema_loaded_from_dynamo[:table][:local_secondary_indexes] || @schema_loaded_from_dynamo[:table][:global_secondary_indexes]
          ((@schema_loaded_from_dynamo[:table][:local_secondary_indexes] || []) + (@schema_loaded_from_dynamo[:table][:global_secondary_indexes] || [])).each do |key|
            si_range_key = key[:key_schema].find{|h| h[:key_type] == "RANGE" }
            next if si_range_key.nil?
            si_range_attribute = @table_schema[:attribute_definitions].find{|h| h[:attribute_name] == si_range_key[:attribute_name]}
            next if si_range_attribute.nil?
            (@range_keys ||= []) << {
              :attribute_name => si_range_key[:attribute_name],
              :attribute_type => si_range_attribute[:attribute_type],
              :index_name => key[:index_name]
            }
          end
        end

        @schema_loaded_from_dynamo
      end

      def hash_key_item_param(value)
        hash_key = @table_schema[:key_schema].find{|h| h[:key_type] == "HASH"}[:attribute_name]
        hash_key_type = @table_schema[:attribute_definitions].find{|h| h[:attribute_name] == hash_key}[:attribute_type]
        { hash_key => { hash_key_type => value } }
      end

      def hash_key_condition_param(hash_key, value)
        hash_key_type = @table_schema[:attribute_definitions].find{|h| h[:attribute_name] == hash_key}[:attribute_type]
        {
          hash_key => {
            :attribute_value_list => [hash_key_type => value],
            :comparison_operator => COMPARISON_OPERATOR[:eq]
          }
        }
      end

      def attr_with_type(attr_name, value)
        { attr_name => { TYPE_INDICATOR[type_from_value(value)] => value.to_s } }
      end

      def get_item(hash_key, options={})
        options[:consistent_read] = false unless options[:consistent_read]
        options[:return_consumed_capacity] ||= :none # "NONE" # || "TOTAL"
        options[:select] ||= []

        get_item_request = {
          :table_name => options[:table_name] || self.table_name,
          :key => hash_key_item_param(hash_key),
          :consistent_read => options[:consistent_read],
          :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]]
        }
        get_item_request.merge!( :attributes_to_get => [options[:select]].flatten ) unless options[:select].blank?
        @client.get_item(get_item_request)
      end

      # == options
      #    * consistent_read
      #    * return_consumed_capacity
      #    * order
      #    * select
      #    * range
      def query(hash_key_value, options={})
        options[:consistent_read] = false unless options[:consistent_read]
        options[:return_consumed_capacity] ||= :none # "NONE" # || "TOTAL"
        options[:order] ||= :desc
        #options[:index_name] ||= :none
        #AWS::DynamoDB::Errors::ValidationException: ALL_PROJECTED_ATTRIBUTES can be used only when Querying using an IndexName
        #options[:limit] ||= 10
        #options[:exclusive_start_key]

        key_conditions = {}
        gsi = nil
        if options[:global_secondary_index]
          # TODO
          gsi = @table_schema[:global_secondary_indexes].select{ |gsi| gsi[:index_name].to_s == options[:global_secondary_index].to_s}.first
          raise ArgumentError, "Could not find Global Secondary Index '#{options[:global_secondary_index]}'" unless gsi
          gsi_hash_key = gsi[:key_schema].find{|h| h[:key_type] == "HASH"}[:attribute_name]
          key_conditions.merge!(hash_key_condition_param(gsi_hash_key, hash_key_value))
        else
          hash_key = @table_schema[:key_schema].find{|h| h[:key_type] == "HASH"}[:attribute_name]
          key_conditions.merge!(hash_key_condition_param(hash_key, hash_key_value))
        end

        query_request = {
          :table_name => options[:table_name] || self.table_name,
          :key_conditions => key_conditions,
          :consistent_read => options[:consistent_read],
          :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]],
          :scan_index_forward => (options[:order] == :asc)
        }

        if options[:range] 
          raise ArgumentError, "Expected a 1 element Hash for :range (ex {:age.gt => 13})" unless options[:range].is_a?(Hash) && options[:range].keys.size == 1 && options[:range].keys.first.is_a?(String)
          range_key_name, comparison_operator = options[:range].keys.first.split(".")
          raise ArgumentError, "Comparison operator must be one of (#{(COMPARISON_OPERATOR.keys - COMPARISON_OPERATOR_SCAN_ONLY).join(", ")})" unless COMPARISON_OPERATOR.keys.include?(comparison_operator.to_sym)
          range_key = nil
          #[{:attribute_name=>"health_check_guid", :attribute_type=>"S", :primary_range_key=>true}]
          #raise @range_keys.inspect
          #if options[:global_secondary_index]
            #raise @table_schema.inspect
            #hash_key_type = @table_schema[:attribute_definitions].find{|h| h[:attribute_name] == hash_key}[:attribute_type]
            #raise gsi[:key_schema].inspect
            ##range_key = gsi.find{|k| k[:attribute_name] == range_key_name}
          #else
            range_key = @range_keys.find{|k| k[:attribute_name] == range_key_name}
          #end
          raise ArgumentError, ":range key must be a valid Range attribute" unless range_key
          raise ArgumentError, ":range key must be a Range if using the operator BETWEEN" if comparison_operator == "between" && !options[:range].values.first.is_a?(Range)

          if range_key.has_key?(:index_name) # Local/Global Secondary Index
            query_request.merge!(:index_name => range_key[:index_name])
          end

          range_value = options[:range].values.first
          range_attribute_list = []
          if comparison_operator == "between"
            range_attribute_list << { range_key[:attribute_type] => range_value.min }
            range_attribute_list << { range_key[:attribute_type] => range_value.max }
          else
            # TODO - support Binary?
            range_attribute_list = [{ range_key[:attribute_type] => range_value.to_s }]
          end

          key_conditions.merge!({
            range_key[:attribute_name] => {
              :attribute_value_list => range_attribute_list,
              :comparison_operator => COMPARISON_OPERATOR[comparison_operator.to_sym]
            }
          })
        end

        if options[:global_secondary_index] # Override index_name if using GSI
          options[:select] = :projected if options[:select].blank?
          query_request.merge!(:index_name => gsi[:index_name])
        end
        options[:select] ||= :all # :all, :projected, :count, []
        if options[:select].is_a?(Array)
          attrs_to_select = [options[:select].map(&:to_s)].flatten
          attrs_to_select << @hash_key[:attribute_name]
          attrs_to_select << @primary_range_key[:attribute_name] if @primary_range_key
          query_request.merge!({
            :select => QUERY_SELECT[:specific],
            :attributes_to_get => attrs_to_select.uniq
          })
        else
          query_request.merge!({ :select => QUERY_SELECT[options[:select]] })
        end
        
        query_request.merge!({ :limit => options[:limit].to_i }) if options.has_key?(:limit)
        query_request.merge!({ :exclusive_start_key => options[:exclusive_start_key] }) if options[:exclusive_start_key]

        @client.query(query_request)
      end

      def batch_get_item(keys, options={})
        options[:return_consumed_capacity] ||= :none
        options[:select] ||= []
        options[:consistent_read] = false unless options[:consistent_read]

        raise ArgumentError, "must include between 1 - 100 keys" if keys.size == 0 || keys.size > 100
        keys_request = []
        keys.each do |k|
          key_request = {}
          if @primary_range_key
            hash_value = k[:hash_value]
          else
            raise ArgumentError, "expected keys to be in the form of ['hash key here'] for table with no range keys" if hash_value.is_a?(Hash)
            hash_value = k
          end
          raise ArgumentError, "every key must include a :hash_value" if hash_value.blank?
          key_request[@hash_key[:attribute_name]] = { @hash_key[:attribute_type] => hash_value.to_s }
          if @primary_range_key
            range_value = k[:range_value]
            raise ArgumentError, "every key must include a :range_value" if range_value.blank?
            key_request[@primary_range_key[:attribute_name]] = { @primary_range_key[:attribute_type] => range_value.to_s }
          end
          keys_request << key_request
        end

        request_items_request = {}
        request_items_request.merge!( :keys => keys_request )
        request_items_request.merge!( :attributes_to_get => [options[:select]].flatten ) unless options[:select].blank?
        request_items_request.merge!( :consistent_read => options[:consistent_read] ) if options[:consistent_read]
        batch_get_item_request = {
          :request_items => { (options[:table_name] || self.table_name) => request_items_request },
          :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]]
        }
        @client.batch_get_item(batch_get_item_request)
      end

      def write(hash_key_value, attributes, options={})
        options[:return_consumed_capacity] ||= :none
        options[:update_item] = false unless options[:update_item]

        if options[:update_item]
          # UpdateItem
          key_request = {
            @hash_key[:attribute_name] => {
              @hash_key[:attribute_type] => hash_key_value.to_s
            }
          }
          if @primary_range_key
            range_key_value = attributes[@primary_range_key[:attribute_name]]
            raise ArgumentError, "range_key was not provided to the write command" if range_key_value.blank?
            key_request.merge!({
              @primary_range_key[:attribute_name] => {
                @primary_range_key[:attribute_type] => range_key_value.to_s
              }
            })
          end
          attrs_to_update = {}
          attributes.each_pair do |k,v|
            next if @primary_range_key && k == @primary_range_key[:attribute_name]
            if v.blank?
              attrs_to_update.merge!({ k => { :action => "DELETE" } })
            else
              attrs_to_update.merge!({
                k => {
                  :value => attr_with_type(k,v).values.last,
                  :action => "PUT"
                }
              })
            end
          end
          update_item_request = {
            :table_name => options[:table_name] || self.table_name,
            :key => key_request,
            :attribute_updates => attrs_to_update,
            :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]]
          }
          @client.update_item(update_item_request)
        else
          # PutItem
          items = {}
          attributes.each_pair do |k,v|
            next if v.blank? # If empty string or nil, skip...
            items.merge!(attr_with_type(k,v))
          end
          items.merge!(hash_key_item_param(hash_key_value))
          put_item_request = {
            :table_name => options[:table_name] || self.table_name,
            :item => items,
            :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]]
          }
          @client.put_item(put_item_request)
        end
      end

      def delete_item(hash_key_value, options={})
        key_request = {
          @hash_key[:attribute_name] => {
            @hash_key[:attribute_type] => hash_key_value.to_s
          }
        }
        if @primary_range_key
          raise ArgumentError, "range_key was not provided to the delete_item command" if options[:range_value].blank?
          key_request.merge!({
            @primary_range_key[:attribute_name] => {
              @primary_range_key[:attribute_type] => options[:range_value].to_s
            }
          })
        end
        delete_item_request = {
          :table_name => options[:table_name] || self.table_name,
          :key => key_request
        }
        @client.delete_item(delete_item_request)
      end

      def type_from_value(value)
        case
        when value.kind_of?(AWS::DynamoDB::Binary) then :b
        when value.respond_to?(:to_str) then :s
        when value.kind_of?(Numeric) then :n
        when value.respond_to?(:each)
          indicator = nil
          value.each do |v|
            member_indicator = type_indicator(v)
            raise ArgumentError, "nested collections" if member_indicator.to_s.size > 1
            raise ArgumentError, "mixed types" if indicator and member_indicator != indicator
            indicator = member_indicator
          end
          indicator ||= :s
          :"#{indicator}s"
        else
          raise ArgumentError, "unsupported attribute type #{value.class}"
        end
      end

      # Perform a table scan
      # http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html
      def scan(options={})
        options[:return_consumed_capacity] ||= :none # "NONE" # || "TOTAL"
        # Default if not already set
        options[:select] ||= :all # :all, :projected, :count, []

        scan_request = {
          :table_name => options[:table_name] || self.table_name,
          :return_consumed_capacity => RETURNED_CONSUMED_CAPACITY[options[:return_consumed_capacity]]
        }

        scan_request.merge!({ :limit => options[:limit].to_i }) if options.has_key?(:limit)
        scan_request.merge!({ :exclusive_start_key => options[:exclusive_start_key] }) if options[:exclusive_start_key]

        if options[:select].is_a?(Array)
          attrs_to_select = [options[:select].map(&:to_s)].flatten
          attrs_to_select << @hash_key[:attribute_name]
          attrs_to_select << @primary_range_key[:attribute_name] if @primary_range_key
          scan_request.merge!({
            :select => QUERY_SELECT[:specific],
            :attributes_to_get => attrs_to_select.uniq
          })
        else
          scan_request.merge!({ :select => QUERY_SELECT[options[:select]] })
        end

        # :scan_filter => { :name.begins_with => "a" }
        scan_filter = {}
        if options[:scan_filter].present?
          options[:scan_filter].each_pair.each do |k,v|
            # Hard to validate attribute types here, so infer by type sent and assume the user knows their own attrs
            key_name, comparison_operator = k.split(".")
            raise ArgumentError, "Comparison operator must be one of (#{COMPARISON_OPERATOR.keys.join(", ")})" unless COMPARISON_OPERATOR.keys.include?(comparison_operator.to_sym)
            raise ArgumentError, "scan_filter value must be a Range if using the operator BETWEEN" if comparison_operator == "between" && !v.is_a?(Range)
            raise ArgumentError, "scan_filter value must be a Array if using the operator IN" if comparison_operator == "in" && !v.is_a?(Array)

            attribute_value_list = []
            if comparison_operator == "in"
              v.each do |in_v|
                attribute_value_list << attr_with_type(key_name, in_v).values.last
              end
            elsif comparison_operator == "between"
              attribute_value_list << attr_with_type(key_name, range_value.min).values.last
              attribute_value_list << attr_with_type(key_name, range_value.max).values.last
            else
              attribute_value_list << attr_with_type(key_name, v).values.last
            end
            scan_filter.merge!({
              key_name => {
                :comparison_operator => COMPARISON_OPERATOR[comparison_operator.to_sym],
                :attribute_value_list => attribute_value_list
              }
            })
          end
          scan_request.merge!(:scan_filter => scan_filter)
        end

        scan_request.merge!({ :segment => options[:segment].to_i }) if options[:segment].present?
        scan_request.merge!({ :total_segments => options[:total_segments].to_i }) if options[:total_segments].present?

        @client.scan(scan_request)
      end

      # Call proc or return string
      def table_name
        if @table_schema[:table_name].respond_to?(:call)
          @table_schema[:table_name].call
        else
          @table_schema[:table_name]
        end
      end

      def create(options={})
        if @client.list_tables[:table_names].include?(options[:table_name] || self.table_name)
          raise "Table #{options[:table_name] || self.table_name} already exists"
        end

        @client.create_table(@table_schema.merge({
          :table_name => options[:table_name] || self.table_name
        }))

        while (table_metadata = self.describe(options))[:table][:table_status] == "CREATING"
          sleep 1
        end

        self.load_schema
        table_metadata
      end

      def describe(options={})
        @client.describe_table(:table_name => options[:table_name] || self.table_name)
      end

      def delete(options={})
        return false unless @client.list_tables[:table_names].include?(options[:table_name] || self.table_name)
        @client.delete_table(:table_name => options[:table_name] || self.table_name)
        begin
          while (table_metadata = self.describe) && table_metadata[:table][:table_status] == "DELETING"
            sleep 1
          end
        rescue AWS::DynamoDB::Errors::ResourceNotFoundException => e
          Toy::Dynamo::Config.logger.info "Table deleted"
        end
        true
      end

      def resize(options={})
        return false unless @client.list_tables[:table_names].include?(options[:table_name] || self.table_name)
        @client.update_table({
          :provisioned_throughput => {
            :read_capacity_units => (options[:read_capacity_units] || @table_schema[:provisioned_throughput][:read_capacity_units]).to_i,
            :write_capacity_units => (options[:write_capacity_units] || @table_schema[:provisioned_throughput][:write_capacity_units]).to_i
          },
          :table_name => options[:table_name] || self.table_name
        })
        while (table_metadata = self.describe) && table_metadata[:table][:table_status] == "UPDATING"
          sleep 1
        end
        Toy::Dynamo::Config.logger.info "Table resized to #{table_metadata[:table][:provisioned_throughput]}"
        true
      end

    end
  end
end
