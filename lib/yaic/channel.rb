# frozen_string_literal: true

module Yaic
  class Channel
    attr_reader :name, :topic, :topic_setter, :topic_time, :users, :modes

    def initialize(name)
      @name = name
      @topic = nil
      @topic_setter = nil
      @topic_time = nil
      @users = {}
      @modes = {}
    end
  end
end
