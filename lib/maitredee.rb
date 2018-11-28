require "json"
require "json_schemer"
require "set"
require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/json"
require "active_support/json"
require "pathname"
require "maitredee/publisher"
require "maitredee/subscriber"
require "maitredee/version"
require "maitredee/adapters/sns_sqs_adapter"

module Maitredee
  class << self
    attr_accessor :resource_name_suffix, :schema_path
    attr_reader :client
    attr_writer :app_name, :namespace

    def publish(
      topic:,
      body:,
      validation_schema:,
      event_name: nil,
      primary_key: nil
    )
      raise ArgumentError, "topic, body or validation_schema is nil" if topic.nil? || body.nil? || validation_schema.nil?
      body = body.as_json
      validate!(body, validation_schema)

      message = PublisherMessage.new(
        message_id: SecureRandom.uuid,
        topic_resource_name: topic_resource_name(topic),
        topic: topic,
        body: body,
        validation_schema: validation_schema&.to_s,
        event_name: event_name&.to_s,
        primary_key: primary_key&.to_s
      )

      client.publish(message)

      message
    end

    def set_client(slug, *args)
      raise "No client set for Maitredee" if slug.nil?
      @client = "::Maitredee::Adapters::#{slug.to_s.camelize}Adapter".constantize.new(*args)
    end

    def client=(slug)
      set_client(slug)
    end

    def topic_resource_name(topic_name)
      [
        namespace,
        topic_name,
        resource_name_suffix
      ].compact.join("--")
    end

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

    def validate!(body, schema)
      errors = schemas[schema].validate(body.as_json)
      properties = errors.map do |error|
        error["data_pointer"]
      end.join(", ")

      if errors.any?
        raise ValidationError, "Invalid properties: #{properties}"
      end
    end

    def schemas
      @schemas ||= Hash.new do |hash, key|
        path = Pathname.new(schema_path).join("#{key}.json")
        hash[key] = JSONSchemer.schema(path)
      end
    end

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

    def namespace
      @namespace ||=
        ENV["MAITREDEE_NAMESPACE"] || raise("must set namespace for maitredee")
    end

    def configure_broker
      hash_array = Hash.new { |hash, key| hash[key] = [] }
      topics_and_queues =
        subscriber_registry.each_with_object(hash_array) do |subscriber, hash|
          topic_arn = topic_resource_name(subscriber.topic_name)
          hash[topic_arn] << queue_resource_name(subscriber.topic_name, subscriber.queue_name)
        end
      client.configure_broker(topics_and_queues)
    end

    def register_subscriber(klass)
      client.add_worker(klass)
      subscriber_registry.add(klass)
    end

    def subscriber_registry
      @subscriber_registry ||= Set.new
    end
  end

  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)
  NoRoutesError = Class.new(Error)

  PublisherMessage = Struct.new(
    :message_id, :topic_resource_name, :topic, :body, :validation_schema,
    :event_name, :primary_key, keyword_init: true
  )

  SubscriberMessage = Struct.new(
    :message_id, :broker_message_id, :topic_name, :event_name, :primary_key, :schema_name, :body,
    :sent_at, :maitredee_version, :raw_message, :adapter_message, keyword_init: true
  )
end
