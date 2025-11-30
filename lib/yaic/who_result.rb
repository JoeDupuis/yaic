# frozen_string_literal: true

module Yaic
  class WhoResult
    attr_reader :channel, :user, :host, :server, :nick, :away, :realname

    def initialize(channel:, user:, host:, server:, nick:, away:, realname:)
      @channel = channel
      @user = user
      @host = host
      @server = server
      @nick = nick
      @away = away
      @realname = realname
    end
  end
end
