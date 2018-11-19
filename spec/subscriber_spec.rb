require "spec_helper"

RSpec.describe Maitredee::Subscriber do
  class NoDefaultsSubscriber < Maitredee::Subscriber
    subscribe_to :no_defaults do
      event :update, minimum_schema: :recipe_v1
      event :delete, to: :process
      event nil, to: :process
    end

    def process
      self.class.messages[:process] << message
    end

    def update
      self.class.messages[:update] << message
    end

    def self.messages
      @messages ||= Hash.new { |hash, key| hash[key] = [] }
    end
  end

  class DefaultsSubscriber < Maitredee::Subscriber
    subscribe_to :defaults do
      event :update

      default_event to: :default
    end

    def default
      self.class.messages[:default] << message
    end

    def update
      self.class.messages[:update] << message
    end

    def self.messages
      @messages ||= Hash.new { |hash, key| hash[key] = [] }
    end
  end

  before do
    NoDefaultsSubscriber.messages.clear
    DefaultsSubscriber.messages.clear
  end

  describe "#perform" do
    let(:recipe_params) do
      {
        body: {
          id: "1",
          name: "Bibimbap",
          servings: 2,
          calories: 400
        },
        schema_name: :recipe_v2
      }
    end

    context "controller with no defaults" do
      it "update routes to update" do
        controller_perform(
          NoDefaultsSubscriber,
          event_name: :update,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 1
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end

      it "delete routes to process" do
        controller_perform(
          NoDefaultsSubscriber,
          event_name: :delete,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "nil routes to process" do
        controller_perform(
          NoDefaultsSubscriber,
          event_name: nil,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "empty string is routed using nil event to process" do
        controller_perform(
          NoDefaultsSubscriber,
          event_name: "",
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "does not process non routed events" do
        controller_perform(
          NoDefaultsSubscriber,
          event_name: :unrouted,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end
    end

    context "controller with defaults" do
      it "default catches all non routed events" do
        controller_perform(
          DefaultsSubscriber,
          event_name: :unrouted,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end

      it "nil routes to default" do
        controller_perform(
          DefaultsSubscriber,
          event_name: nil,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end
    end

    def controller_perform(controller, body:, event_name: nil, schema_name: nil)
      controller.new.perform(
        shoryuken_message(
          body: body,
          event_name: event_name,
          schema_name: schema_name
        ),
        body
      )
    end

    def shoryuken_message(body:, event_name: nil, schema_name: nil)
      double(
        Shoryuken::Message,
        queue_url: "do-not-care",
        body: body.to_json,
        message_attributes: shoryuken_message_attributes(
          {
            event_name: event_name,
            schema_name: schema_name
          }.compact
        ),
        message_id: SecureRandom.uuid,
        receipt_handle: SecureRandom.uuid
      )
    end

    def shoryuken_message_attributes(hash)
      hash.each_with_object({}) do |(key, val), new_hash|
        new_hash[key.to_s] = double(
          Aws::SQS::Types::MessageAttributeValue,
          data_type: "String",
          string_value: val.to_s
        )
      end
    end
  end

  describe "#subscribe_to#shoryuken_options" do
    it "raise if no events routed" do
      expect {
        class NoRoutesSubscriber < Maitredee::Subscriber
          subscribe_to :no_routes do
          end
        end
      }.to raise_error Maitredee::NoRoutesError
    end

    class NoOptionsSubscriber < Maitredee::Subscriber
      subscribe_to :no_options do
        default_event to: :default
      end
    end

    it "has default options" do
      options = NoOptionsSubscriber.shoryuken_options_hash
      expect(options["queue"]).to eq "test--no_options--maitredee--no-options--#{Maitredee.resource_name_suffix}"
      expect(options["auto_delete"]).to be true
      expect(options["body_parser"]).to be :json
    end
  end
end
