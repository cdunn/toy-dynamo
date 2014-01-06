module Toy
  module Extensions
    module Float
      def to_store(value, *)
        value.nil? ? nil : value.to_f
      end

      def from_store(value, *)
        value.nil? ? nil : value.to_f
      end
    end
  end
end
