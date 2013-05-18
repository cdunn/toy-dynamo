require "toy/dynamo/version"
require "toy/dynamo/adapter"
require "toy/dynamo/schema"
require "toy/dynamo/table"
require "toy/dynamo/tasks"
require "toy/dynamo/querying"
require "toy/dynamo/response"
require "toy/dynamo/persistence"
# Override 'write_attribute' for hash_key == id
require "toy/dynamo/attributes"
require "toy/dynamo/config"
require "toy/dynamo/extensions/array"
require "toy/dynamo/extensions/boolean"
require "toy/dynamo/extensions/date"
require "toy/dynamo/extensions/hash"
require "toy/dynamo/extensions/set"
require "toy/dynamo/extensions/time"
require "toy/dynamo/extensions/symbol"

module Toy
  module Dynamo

    MAX_ITEM_SIZE = 65_536

    extend ActiveSupport::Concern
    include Toy::Store

    include Schema
    include Querying
  end
end
