# frozen_string_literal: true

module Yaic
  class Source
    attr_reader :nick, :user, :host, :raw

    def initialize(nick: nil, user: nil, host: nil, raw: nil)
      @nick = nick
      @user = user
      @host = host
      @raw = raw
    end

    def self.parse(str)
      return nil if str.nil? || str.empty?

      nick = nil
      user = nil
      host = nil

      if str.include?("!")
        nick, rest = str.split("!", 2)
        if rest.include?("@")
          user, host = rest.split("@", 2)
        else
          user = rest
        end
      elsif str.include?("@")
        nick, host = str.split("@", 2)
      elsif str.include?(".")
        host = str
      else
        nick = str
      end

      new(nick: nick, user: user, host: host, raw: str)
    end
  end
end
