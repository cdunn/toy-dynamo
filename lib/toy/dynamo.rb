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
require "toy/dynamo/store"
require "toy/dynamo/extensions/array"
require "toy/dynamo/extensions/boolean"
require "toy/dynamo/extensions/date"
require "toy/dynamo/extensions/hash"
require "toy/dynamo/extensions/set"
require "toy/dynamo/extensions/time"
require "toy/dynamo/extensions/symbol"

module Toy
  module Dynamo
    extend self

    def configure
      block_given? ? yield(Toy::Dynamo::Config) : Toy::Dynamo::Config
    end
    alias :config :configure

    def logger
      Toy::Dynamo::Config.logger
    end

  end
end
