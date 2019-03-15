require "active_support/core_ext/class/subclasses"
require "active_job"

module Maitredee
  module ActiveJob
    def self.extended(mod)
      mod.descendants.each do |klass|
        create_publisher_job(klass)
      end
    end

    # @api private
    def self.create_publisher_job(subclass)
      subclass.const_set("PublisherJob", Class.new(BasePublisherJob))
      subclass::PublisherJob.service_class = subclass
    end

    # Uses ActiveJob to async the publishing
    # @example To configure the specific async job open PublisherJob
    #   class RecipePublisher < Maitredee::Publisher
    #     class PublisherJob
    #       queue_as :low
    #     end
    #   end
    #
    #   RecipePublisher.call_later(Recipe.find(1))
    #
    def call_later(*args)
      self::PublisherJob.perform_later(*args)
    end

    # Like `call_later`, but performs at a given time
    # @example Configuring a time to perform the job
    #   RecipePublisher.call_later_at(Date.tomorrow.noon, Recipe.find(1))
    #
    def call_later_at(at, *args)
      self::PublisherJob.set(wait_until: at).perform_later(*args)
    end

    private

    def inherited(subclass)
      create_publisher_job(subclass)
      super
    end

    def create_publisher_job(subclass)
      Maitredee::ActiveJob.create_publisher_job(subclass)
    end

    # @private
    class BasePublisherJob < ::ActiveJob::Base
      class << self
        attr_accessor :service_class
      end

      def perform(*args)
        self.class.service_class.call(*args)
      end
    end

    ::Maitredee::Publisher.extend(self)
  end
end
