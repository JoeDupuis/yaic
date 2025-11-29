# frozen_string_literal: true

module Yaic
  class Event
    attr_reader :type, :message

    def initialize(type:, message: nil, **attributes)
      @type = type
      @message = message
      @attributes = attributes
    end

    def [](key)
      @attributes[key]
    end

    def to_h
      @attributes.dup
    end

    private

    def respond_to_missing?(method_name, include_private = false)
      @attributes.key?(method_name) || super
    end

    def method_missing(method_name, *args)
      if @attributes.key?(method_name) && args.empty?
        @attributes[method_name]
      else
        super
      end
    end
  end
end
