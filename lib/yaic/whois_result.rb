# frozen_string_literal: true

module Yaic
  class WhoisResult
    attr_accessor :nick, :user, :host, :realname, :channels, :server, :idle, :signon, :account, :away

    def initialize(nick:)
      @nick = nick
      @user = nil
      @host = nil
      @realname = nil
      @channels = []
      @server = nil
      @idle = nil
      @signon = nil
      @account = nil
      @away = nil
    end
  end
end
