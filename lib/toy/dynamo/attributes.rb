module Toy
  module Attributes

    # [OVERRIDE] 'write_attribute' to account for setting hash_key and id to same value
    # u.id = 1
    # * set id to 1
    # * set hash_key to 1
    # u.hash_key = 2
    # * set hash_key to 2
    # * set id to 2
    def write_attribute(key, value)
      key = key.to_s
      attribute = attribute_instance(key)

      if self.class.dynamo_table.hash_key[:attribute_name] != "id" # If primary hash_key is not the standard `id`
        if key == self.class.dynamo_table.hash_key[:attribute_name]
          @attributes[key] = attribute_instance(key).from_store(value)
          return @attributes["id"] = attribute_instance("id").from_store(value)
        elsif key == "id"
          @attributes["id"] = attribute_instance("id").from_store(value)
          return @attributes[self.class.dynamo_table.hash_key[:attribute_name]] = attribute_instance(self.class.dynamo_table.hash_key[:attribute_name]).from_store(value)
        end
      end

      @attributes[key] = attribute.from_store(value)
    end

  end
end
