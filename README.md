# Maitredee

An opinionated pub/sub framework.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
- [Publisher](#publisher)
- [Subscriber](#subscriber)
- [Validation schema](#validation-schema)
- [Misc](#misc)
    - [Development](#development)
    - [Contributing](#contributing)
    - [License](#license)
    - [Code of Conduct](#code-of-conduct)

## Overview
We made maitredee to simplify publishing and subscribing to events for our junior developers. We tried using kafka but ordered eventing was too complicated.

We tried to have zero setup required to get this up and running and make it work as simply as sidekiq.

We hope in the future to add more adapters beyond sns/sqs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'maitredee'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install maitredee

## Configuration

Required Configuration
```ruby
Maitredee.namespace = "plated-production"
Maitredee.schema_path = Rails.root.join("your/path").to_s
Maitredee.client = :sns_sqs
```

These namespace can also be set with the environment variable MAITREDEE_NAMESPACE

### Available clients

Maitredee currently supports the following clients:

#### SNS/SQS :sns_sqs
You can set the AWS parameters in a variety of ways.
Either environment variables or explicitly.
Supported environment variables are MAITREDEE_AWS_ACCESS_KEY_ID, MAITREDEE_AWS_SECRET_ACCESS_KEY, MAITREDEE_AWS_REGION and then falls back to default AWS keys.

if you wish to set it explicitly:
```ruby
Maitredee.set_client(
  :sns_sqs,
  access_key_id: "",
  secret_access_key: "",
  region: ""
)
```

#### Test :test

This is used for testing.

```ruby
Maitredee.client = :test
```

When you pubish anything through Maitredee it will be logged in the test client for test verification.

You should reset the client at the beginning of every test with `Maitredee.client.reset`

## Publisher

Create a publisher class for your topic and inherit from `Maitredee::Publisher`
Optionally define the default topic, event_name, or validation schema with `publish_defaults`

```ruby goodread
require "maitredee"

class MyPublisher < Maitredee::Publisher
  publish_defaults(
    topic_name: :your_default_topic,
    event_name: :your_default_event_name,
    schema_name: :your_default_schema
  )
end
```

Maitredee will call `process` on your publisher when it is called. Define a method `process` that calls `publish` with the parameters of your choosing.  `Publish` will default the `topic`, `event_name`, and `schema_name` from your publish_defaults if not given.    
```ruby goodread
class MyPublisher < Maitredee::Publisher
  def process
    publish(
      topic_name: :my_topic,
      event_name: :event_name_is_optional,
      schema_name: :schema_name,
      primary_key: "optionalKey",
      body: {}
    )
  end
end
```

### Publishing a message
To publish a message, simply call `call` on your publisher:
```ruby
MyPublisher.call(message)
```

Publish will first validate your schema before publishing the message.

If you have ActiveJob you can also `#call_later` and it will be called asyncronously

## Subscriber

```ruby
class RecipeSubscriber < Maitredee::Subscriber
  # this is the topic name
  subscribe_to :recipes do

    # this is the event name optionally say which method to use to process
    event(:create, to: create)

    # event_name will be used as the method name if it is a valid method name, otherwise to: must be set
    event(:delete)

    # for empty event name just use nil
    event(nil, to: :process)

    # you can specify a catch all route
    default_event to: :process
  end

  def create
    Recipe.create!(message.body)
  end

  def process
    Recipe.find(message.body[:id]).update(message.body)
  end

  def delete
    Recipe.find(message.body[:id]).destroy
  end
end
```

## Validating Schemas
Maitredee validates your message body schemas using JSON schema ([JSON-schemer] (https://github.com/davishmcclurg/json_schemer)) for both publishing and consuming messages.  [Configure] (#configuration) the location of your schemas and provide a JSON file for each of your schemas.

Example `recipe_v1.json`:
```json
{
  "type": "object",
  "required": ["id", "name", "servings"],
  "properties": {
    "id": {
      "type": "string"
    },
    "name": {
      "type": "string"
    },
    "servings": {
      "type": "number"
    }
  }
}

```

## Misc

### Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/plated/maitredee. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### Code of Conduct

Everyone interacting in the Maitredee project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/plated/maitredee/blob/master/CODE_OF_CONDUCT.md).
