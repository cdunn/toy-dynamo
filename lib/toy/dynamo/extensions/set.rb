module Toy
  module Extensions
    module Set
      def store_default
        [].to_set
      end

      def to_store(value, *)
        Marshal.dump(value)
      end

      def from_store(value, *)
        value.nil? ? store_default : Marshal.load(value)
      end
    end
  end
end
