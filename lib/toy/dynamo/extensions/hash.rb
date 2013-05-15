module Toy
  module Extensions
    module Hash
      def to_store(value, *)
        Marshal.dump(value)
      end

      def from_store(value, *)
        value.nil? ? store_default : (value.class.is_a?(Hash) ? value : Marshal.load(value))
      end
    end
  end
end
