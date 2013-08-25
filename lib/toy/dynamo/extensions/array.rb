module Toy
  module Extensions
    module Array
      def to_store(value, *)
        value = value.respond_to?(:lines) ? value.lines : value
        AWS::DynamoDB::Binary.new(Marshal.dump(value.to_a))
      end

      def from_store(value, *)
        value.nil? ? store_default : (value.class.is_a?(Array) ? value : Marshal.load(value))
      end
    end
  end
end
