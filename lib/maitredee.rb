require "json"
require "json_schemer"
require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/json"
require "pathname"
require "maitredee/publisher"
require "maitredee/adapters/sns_adapter"

module Maitredee
  class << self
    attr_accessor :topic_prefix, :schema_path
    attr_reader :client
    attr_writer :env

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

      message = Message.new(
        topic_resource_name: topic_resource_name(topic),
        topic: topic,
        body: body,
        validation_schema: validation_schema,
        event_name: event_name,
        primary_key: primary_key&.to_s
      )

      client.publish(message)

      message
    end

    def client=(slug)
      @client = "::Maitredee::Adapters::#{slug.to_s.camelize}Adapter".constantize.new
    end

    def topic_resource_name(name)
      [
        topic_prefix,
        env,
        name
      ].join("--")
    end

    def validate!(body, schema)
      errors = schemas[schema].validate(body.as_json)
      properties = errors.map do |error|
        error["data_pointer"]
      end.join(", ")

      if properties.present?
        raise ValidationError, "Invalid properties: #{properties}"
      end
    end

    def schemas
      @schemas ||= Hash.new do |hash, key|
        path = Pathname.new(schema_path).join("#{key}.json")
        hash[key] = JSONSchemer.schema(path)
      end
    end

    def env
      @env ||= ENV["MAITREDEE_ENV"] || ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
    end
  end

  self.topic_prefix = "maitredee"
  self.client = :sns

  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)

  Message = Struct.new(
    :topic_resource_name, :topic, :body, :validation_schema,
    :event_name, :primary_key, keyword_init: true
  )
end
