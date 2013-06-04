## Overview
toy-dynamo is an ORM for AWS DynamoDB.  It is an extension to [toystore](https://github.com/jnunemaker/toystore) that provides an ActiveModel based ORM for schema-less data stores.

> **Toy::Object** comes with all the goods you need for plain old ruby objects -- attributes, dirty attribute tracking, equality, inheritance, serialization, cloning, logging and pretty inspecting.

> **Toy::Store** includes Toy::Object and adds identity, persistence and querying through adapters, mass assignment, callbacks, validations and a few simple associations (lists and references).

## Install
* toystore gem
	* originally [https://github.com/jnunemaker/toystore](https://github.com/jnunemaker/toystore)
	* Rails 4 compat: [https://github.com/cdunn/toystore](https://github.com/cdunn/toystore) (until merge)
* Official [aws-sdk](http://aws.amazon.com/sdkforruby/) gem

## Config
In ActiveModel model:

```
class Comment

	include Toy::Dynamo::Store

	adapter :dynamo, Toy::Dynamo::Adapter.default_client, {:model => self}

  dynamo_table do
    hash_key :thread_guid
    range_key :comment_guid
    local_secondary_index :posted_by
    read_provision 50
    write_provision 10
  end
	
	attribute :thread_guid, String
	attribute :comment_guid, String, :default => lambda { SimpleUUID::UUID.new.to_guid }
	attribute :body, String
	attribute :posted_by, String
	
end
```
* **Other options for 'dynamo_table' config:**
	* hash_key :comment_id
	* range_key :comment_id
	* table_name "user_dynamo_table"
	* read_provision 20
    * write_provision 10
	* local_secondary_index :created_at
		* :projection => :keys_only **[default]**
		* :projection => :all
		* Can also specify an Array of attributes to project besides the primary keys ex:
			* :projection => [:subject, :commenter_name]
* **aws-sdk config:**
  * [http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/Core/Configuration.html](http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/Core/Configuration.html)


## Basic Usage (toystore)
* **Read Hash Key Only**
	* Example:
		* Model.read("xyz")
		* Model.read("xyz", :consistent_read => true)
* **Read Hash + Range**
	* Example:
		* Model.read("xyz", :range_value => "123")
		* Model.read("xyz", :range_value => "123", :consistent_read => true)
* **Read Multiple Hash Key Only**
	* Example:
		* Model.read_multiple(["abc", "xyz"])
	* **Returns** Hash of Hash Keys => Object
* **Read Multiple Hash + Range**
	* Example:
		* Model.read_multiple([{:hash_value => "xyz", :range_value => "123"}, {:hash_value => "xyz", :range_value => "456"}], :consistent_read => true)
	* Assumes all the same table
	* Runs queries using the batch_get_item API call
	* Limited to 100 items max (or 1MB result size)
	* **Returns** Hash of Hash Keys => Hash of Range keys => Object
* **Read Range**
	* Example:
		* Model.read_range("xyz", :range => {:comment_id.eq => "123"})
		* Model.read_range("xyz", :range => {:comment_id.gte => "123"})
		* Model.read_range("xyz") (any range)
	* If expecting lots of results, use batch and limit
		* Model.read_range("xyz", :batch => 10, :limit => 100)
			* Read 10 at a time up to a max of 100 items
		* Model.read_range("xyz", :limit => 10)
			* Read max 10 items in one request
* **Count Range**
	* Example:
		* Model.count_range("xyz", :range => {:comment_id.eq => "123"})
	* Returns the number of total results (no attributes)

## Extras Usage
* **Init a UUID value**
  * attribute :user_guid, String, :default => lambda { SimpleUUID::UUID.new.to_guid }
* **Use with fake_dynamo**
  * adapter :dynamo, Toy::Dynamo::Adapter.default_client({
      :use_ssl => false,
      :endpoint => 'localhost',
      :port => 4567
    }), {:model => self}
* **Create table**
	* rake ddb:create CLASS=User
	* rake ddb:create CLASS=User TABLE=user-2013-03-14
* **Delete table**
	* rake ddb:delete CLASS=User
	* rake ddb:delete CLASS=User TABLE=user-2013-03-14
* **Resize table read/write capacity**
  * rake ddb:resize CLASS=User READ=50 WRITE=10
  * rake ddb:resize CLASS=User # Use values from model dynamo_table read_provision/write_provision

## Compatibility
* Tested with
	* Rails 4
	* Ruby 2.0.0p0
