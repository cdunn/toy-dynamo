module Toy
  module Extensions
    module Boolean
      def to_store(value, *)
        boolean_value = value.is_a?(Boolean) ? value : Mapping[value]
        boolean_value ? 't' : 'f'
      end

      def from_store(value, *)
        Mapping[value]
      end
    end
  end
end
