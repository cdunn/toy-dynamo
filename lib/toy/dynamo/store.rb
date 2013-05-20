module Toy
  module Dynamo
    module Store

      MAX_ITEM_SIZE = 65_536

      extend ActiveSupport::Concern
      include Toy::Store

      include Schema
      include Querying

    end
  end
end
