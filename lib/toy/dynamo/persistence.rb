module Toy
  module Persistence

    def persisted_attributes
      attributes_with_values = {}
      attributes_to_persist = []

      if self.new_record?
        attributes_to_persist = self.class.persisted_attributes
      else
        attributes_to_persist = self.class.persisted_attributes.select { |a|
          # Persist changed attributes and always the range key if applicable (for lookup)
          self.changed_attributes.keys.include?(a.name) || (self.class.dynamo_table.range_keys && (primary_range_key = self.class.dynamo_table.range_keys.find{|k| k[:primary_range_key]}) && primary_range_key[:attribute_name] == a.name)
        }
      end

      attributes_to_persist.each do |attribute|
        attributes_with_values[attribute.persisted_name] = attribute.to_store(read_attribute(attribute.name))
      end

      attributes_with_values
    end

    def persist
      adapter.write(persisted_id, persisted_attributes, {:update_item => !self.new_record?})
    end

    def delete
      @_destroyed = true
      options = {}
      if self.class.dynamo_table.range_keys && primary_range_key = self.class.dynamo_table.range_keys.find{|k| k[:primary_range_key]}
        options[:range_value] = read_attribute(primary_range_key[:attribute_name])
      end
      adapter.delete(persisted_id, options)
    end

  end
end
