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
        }
      }
    end

    context "subscriber with no defaults" do
      it "update routes to update" do
        NoDefaultsSubscriber.test(
          event_name: :update,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 1
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end

      it "delete routes to process" do
        NoDefaultsSubscriber.test(
          event_name: :delete,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "nil routes to process" do
        NoDefaultsSubscriber.test(
          event_name: nil,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "empty string is routed using nil event to process" do
        NoDefaultsSubscriber.test(
          event_name: "",
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 1
      end

      it "does not process non routed events" do
        NoDefaultsSubscriber.test(
          event_name: :unrouted,
          **recipe_params
        )

        expect(NoDefaultsSubscriber.messages[:update].size).to eq 0
        expect(NoDefaultsSubscriber.messages[:process].size).to eq 0
      end
    end

    context "subscriber with defaults" do
      it "default catches all non routed events" do
        DefaultsSubscriber.test(
          event_name: :unrouted,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end

      it "nil routes to default" do
        DefaultsSubscriber.test(
          event_name: nil,
          **recipe_params
        )

        expect(DefaultsSubscriber.messages[:default].size).to eq 1
        expect(DefaultsSubscriber.messages[:update].size).to eq 0
      end
    end
  end

  describe ".subscribe_to" do
    it "raise if no events routed" do
      expect {
        class NoRoutesSubscriber < Maitredee::Subscriber
          subscribe_to :no_routes do
          end
        end
      }.to raise_error Maitredee::NoRoutesError
    end

    it "raises if invalid event name and nothing routed" do
      expect {
        class InvalidEventNameSubscriber < Maitredee::Subscriber
          subscribe_to :invalid_event_name do
            event "this is an method name"
          end
        end
      }.to raise_error ArgumentError, /not a valid method name/
    end
  end
end
