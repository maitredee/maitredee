require "json"
require "json_schemer"
require "set"
require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "pathname"
require "maitredee/publisher"
require "maitredee/subscriber"
require "maitredee/version"
require "maitredee/adapters/base_adapter"
require "maitredee/adapters/sns_sqs_adapter"
require "maitredee/railtie" if defined? ::Rails::Railtie

module Maitredee
  class << self

    # allows you to add a suffix to all your resource names, mostly used for testing but could be useful in other occassions.
    # @return [String] string appended to all resource names
    attr_accessor :resource_name_suffix

    # this is the path of the folder in which validation_schema will try to do a lookup. This folder should contain json schemas.
    # @return [String] path to folder
    attr_accessor :schema_path

    # the client we use for publishing and setting up workers
    # @return [Maitredee::Adapters::AbstractAdapter]
    attr_reader :client

    # publishes messages using configured adapter
    #
    # @param topic [String] topic name
    # @param body [Hash, Array, String] Any valid json data that can be validated by json-schema
    # @param schema_name [String] A valid schema name for publishing data
    # @param event_name [String, nil] Event name for subscriber routing
    # @param primary_key [#to_s, nil] Key to be used for resource identification
    #
    # @return [PublisherMessage] published message
    def publish(
      topic_name:,
      body:,
      schema_name:,
      event_name: nil,
      primary_key: nil
    )
      raise ArgumentError, "topic_name, body or schema_name is nil" if topic_name.nil? || body.nil? || schema_name.nil?
      validate!(body, schema_name)

      message = PublisherMessage.new(
        message_id: SecureRandom.uuid,
        topic_resource_name: topic_resource_name(topic_name),
        topic_name: topic_name.to_s,
        body: body,
        schema_name: schema_name&.to_s,
        event_name: event_name&.to_s,
        primary_key: primary_key&.to_s
      )

      client.publish(message)

      message
    end

    # configure the adapter, must be executed before loading subscribers
    #
    # @param slug [#to_s] name of adapter
    # @param args [] options to send to the adapter
    def set_client(slug, *args)
      raise "No client set for Maitredee" if slug.nil?
      @client = "::Maitredee::Adapters::#{slug.to_s.camelize}Adapter".constantize.new(*args)
    end

    # set a client without parameters
    #
    # @param slug [#to_s] name of adapter
    def client=(slug)
      set_client(slug)
    end

    # build topic resource name from topic name
    #
    # @param topic_name [#to_s] topic name
    # @return [String]
    def topic_resource_name(topic_name)
      [
        namespace,
        topic_name,
        resource_name_suffix
      ].compact.join("--")
    end

    # build queue resource name from queue name and topic name
    #
    # @param topic_name [#to_s] topic name
    # @param queue_name [#to_s] queue name
    # @return [String]
    def queue_resource_name(topic_name, queue_name)
      [
        namespace,
        topic_name,
        app_name,
        queue_name,
        resource_name_suffix
      ].compact.join("--").tap do |val|
        if val.length > 80
          raise "Cannot have a queue name longer than 80 characters: #{name}"
        end
      end
    end

    # validate a body given a schema name
    #
    # @param body [Array, Hash, String] data to send with message
    # @param schema [String] string key to look up schema to validate against
    #
    # @raise [ValidationError] if validation fails
    # @return [nil]
    def validate!(body, schema)
      errors = schemas[schema].validate(deep_stringify_keys(body))
      properties = errors.map do |error|
        error["data_pointer"]
      end.join(", ")

      if errors.any?
        raise ValidationError, "Invalid properties: #{properties}"
      end
    end

    # hash to look up schema based of schema_path
    #
    # @return Hash[JSONSchemer::Schema::Draft7]
    def schemas
      @schemas ||= Hash.new do |hash, key|
        path = Pathname.new(schema_path).join("#{key}.json")
        hash[key] = JSONSchemer.schema(path)
      end
    end

    # fetch configured app name or automatically fetch from Rails or from `ENV["MAITREDEE_APP_NAME"]`
    # used for generating queue_resource_name
    #
    # @return [String]
    def app_name
      @app_name ||=
        begin
          rails_app_name =
            if defined?(Rails)
              Rails.application.class.parent_name.underscore.dasherize
            end
          ENV["MAITREDEE_APP_NAME"] ||
            rails_app_name ||
            raise("must set app_name for maitredee")
        end
    end

    # set app_name instead of using default
    # @param [String]
    attr_writer :app_name


    # fetch configured namespace or automatically fetch from `ENV["MAITREDEE_NAMESPACE"]`
    # @return [String]
    def namespace
      @namespace ||=
        ENV["MAITREDEE_NAMESPACE"] || raise("must set namespace for maitredee")
    end

    # set namespace instead of using default
    # @param [String]
    attr_writer :namespace

    # idempotently configures broker to create topics, queues and subscribe queues to topics
    # nothing will eveer be deleted or cleaned up
    def configure_broker
      hash_array = Hash.new { |hash, key| hash[key] = [] }
      topics_and_queues =
        subscriber_registry.each_with_object(hash_array) do |subscriber, hash|
          topic_arn = topic_resource_name(subscriber.topic_name)
          hash[topic_arn] << queue_resource_name(subscriber.topic_name, subscriber.queue_name)
        end
      client.configure_broker(topics_and_queues)
    end

    # @api private
    def register_subscriber(klass)
      client.add_worker(klass)
      subscriber_registry.add(klass)
    end

    # @api private
    def subscriber_registry
      @subscriber_registry ||= Set.new
    end

    private

    def deep_stringify_keys(object)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[key.to_s] = deep_stringify_keys(value)
        end
      when Array
        object.map { |e| deep_stringify_keys(e) }
      else
        object
      end
    end
  end

  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)
  NoRoutesError = Class.new(Error)

  PublisherMessage = Struct.new(
    :message_id, :topic_resource_name, :topic_name, :body, :schema_name,
    :event_name, :primary_key, keyword_init: true
  )

  SubscriberMessage = Struct.new(
    :message_id, :broker_message_id, :topic_name, :event_name, :primary_key, :schema_name, :body,
    :sent_at, :maitredee_version, :raw_message, :adapter_message, keyword_init: true
  )
end
