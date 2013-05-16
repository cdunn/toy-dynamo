## Install
* toystore gem
	* originally [https://github.com/jnunemaker/toystore](https://github.com/jnunemaker/toystore)
	* Rails 4 compat: [https://github.com/cdunn/toystore](https://github.com/cdunn/toystore) (until merge)
* Official [aws-sdk](http://aws.amazon.com/sdkforruby/) gem

## Config
In ActiveModel model:

```
dynamo_table do
	adapter :dynamo, AWS::DynamoDB::ClientV2.new, {:model => self}
	hash_key :thread_guid
end
```
* **Other options:**
	* range_key :comment_id
	* table_name "user_dynamo_table"
	* read_provision 20
    * write_provision 10
	* local_secondary_index :created_at
		* :projection => :keys_only **[default]**
		* :projection => :all
		* Can also specify an Array of attributes to project besides the primary keys ex:
			* :projection => [:subject, :commenter_name]

## Usage
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

## Compatibility
* Tested with
	* Rails 4
	* Ruby 2.0.0p0

## TODO
* raise error if trying to use an attribute that wasn't 'select'ed (defaulting to selecting all attributes which loads everything with an extra read)
* while loop for situation where batch_get_item returns batched results
* custom table name per query/write
* default validation for range key presence
* error out on mismatch of table schema from dynamo_table schema (changed?)
