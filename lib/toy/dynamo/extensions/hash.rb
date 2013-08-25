module Toy
  module Extensions
    module Hash
      def to_store(value, *)
        AWS::DynamoDB::Binary.new(Marshal.dump(value))
      end

      def from_store(value, *)
        #begin
          value.nil? ? store_default : (value.class.is_a?(Hash) ? value : Marshal.load(value))
        #rescue ArgumentError => e
          #if e.message =~ /dump format error/
            #Toy::Dynamo::Config.logger.error "Could not unmarshal data!\n\t#{value.inspect}"
            #store_default
          #end
        #end
      end
    end
  end
end
