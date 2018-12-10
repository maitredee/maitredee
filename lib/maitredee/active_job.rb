require "active_support/core_ext/class/subclasses"
require "active_job"

module Maitredee
  module ActiveJob
    def self.extended(mod)
      mod.descendants.each do |klass|
        create_publisher_job(klass)
      end
    end

    def self.create_publisher_job(subclass)
      subclass.const_set("PublisherJob", Class.new(BasePublisherJob))
      subclass::PublisherJob.service_class = subclass
    end

    def call_later(*args)
      self::PublisherJob.perform_later(*args)
    end

    private

    def inherited(subclass)
      create_publisher_job(subclass)
      super
    end

    def create_publisher_job(subclass)
      Maitredee::ActiveJob.create_publisher_job(subclass)
    end

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
