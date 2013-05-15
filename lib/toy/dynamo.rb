require "toy/dynamo/version"
require "toy/dynamo/adapter"
require "toy/dynamo/schema"
require "toy/dynamo/table"
require "toy/dynamo/querying"
require "toy/dynamo/response"
# Override 'write_attribute' for hash_key == id
require "toy/dynamo/attributes"
require "toy/dynamo/extensions/array"
require "toy/dynamo/extensions/boolean"
require "toy/dynamo/extensions/date"
require "toy/dynamo/extensions/hash"
require "toy/dynamo/extensions/set"
require "toy/dynamo/extensions/time"
require "toy/dynamo/extensions/symbol"

module Toy
  module Dynamo
    extend ActiveSupport::Concern
    include Toy::Store

    include Schema
    include Querying
  end
end
