require "spec_helper"

RSpec.describe Maitredee::Subscriber do
  class NoDefaultsSubscriber < Maitredee::Subscriber
    subscribe_to :no_defaults do
      event :update
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

  describe "#process" do
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

    context "subscriber with no defaults" do
      it "update routes to update" do
        subscriber_process(
          NoDefaultsSubscriber,
          event_name: :update,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 1
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end

      it "delete routes to process" do
        subscriber_process(
          NoDefaultsSubscriber,
          event_name: :delete,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "nil routes to process" do
        subscriber_process(
          NoDefaultsSubscriber,
          event_name: nil,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "empty string is routed using nil event to process" do
        subscriber_process(
          NoDefaultsSubscriber,
          event_name: "",
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "does not process non routed events" do
        subscriber_process(
          NoDefaultsSubscriber,
          event_name: :unrouted,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end
    end

    context "subscriber with defaults" do
      it "default catches all non routed events" do
        subscriber_process(
          DefaultsSubscriber,
          event_name: :unrouted,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end

      it "nil routes to default" do
        subscriber_process(
          DefaultsSubscriber,
          event_name: nil,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end
    end

    def subscriber_process(subscriber, body:, event_name: nil, schema_name: nil)
      subscriber.process(
        Maitredee::SubscriberMessage.new(
          message_id: SecureRandom.uuid,
          body: body,
          event_name: event_name,
          schema_name: schema_name,
          broker_message_id: nil,
          topic_name: nil,
          primary_key: nil,
          sent_at: Time.now.to_i,
          maitredee_version: nil,
          raw_message: nil,
          adapter_message: nil
        )
      )
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
  end
end
