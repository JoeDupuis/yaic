# frozen_string_literal: true

module Yaic
  class Client
    STALE_TIMEOUT = 180

    EVENT_MAP = {
      "PRIVMSG" => :message,
      "NOTICE" => :notice,
      "JOIN" => :join,
      "PART" => :part,
      "QUIT" => :quit,
      "KICK" => :kick,
      "NICK" => :nick,
      "TOPIC" => :topic,
      "MODE" => :mode
    }.freeze

    attr_reader :state, :nick, :isupport, :last_received_at

    def initialize(host:, port:, nick: nil, user: nil, realname: nil, password: nil, ssl: false)
      @host = host
      @port = port
      @nick = nick
      @user = user || nick
      @realname = realname || nick
      @password = password
      @ssl = ssl

      @socket = nil
      @state = :disconnected
      @isupport = {}
      @nick_attempts = 0
      @last_received_at = nil
      @handlers = {}
    end

    def connect
      @socket ||= Socket.new(@host, @port, ssl: @ssl)
      @socket.connect
      @state = :connecting
    end

    def disconnect
      @socket&.disconnect
      @state = :disconnected
    end

    def on_socket_connected
      @state = :registering
      send_registration
    end

    def handle_message(message)
      @last_received_at = Time.now

      case message.command
      when "PING"
        handle_ping(message)
      when "001"
        handle_rpl_welcome(message)
      when "005"
        handle_rpl_isupport(message)
      when "433"
        handle_err_nicknameinuse(message)
      end

      emit_events(message)
    end

    def connection_stale?
      return false if @last_received_at.nil?
      Time.now - @last_received_at > STALE_TIMEOUT
    end

    def on(event_type, &block)
      @handlers[event_type] ||= []
      @handlers[event_type] << block
      self
    end

    def off(event_type)
      @handlers.delete(event_type)
      self
    end

    def privmsg(target, text)
      message = Message.new(command: "PRIVMSG", params: [target, text])
      @socket.write(message.to_s)
    end

    alias_method :msg, :privmsg

    def notice(target, text)
      message = Message.new(command: "NOTICE", params: [target, text])
      @socket.write(message.to_s)
    end

    private

    def send_registration
      if @password
        @socket.write(Registration.pass_message(@password).to_s)
      end
      @socket.write(Registration.nick_message(@nick).to_s)
      @socket.write(Registration.user_message(@user, @realname).to_s)
    end

    def handle_rpl_welcome(message)
      @nick = message.params[0] if message.params[0]
      @state = :connected
    end

    def handle_rpl_isupport(message)
      message.params[1..-2].each do |param|
        next unless param

        if param.include?("=")
          key, value = param.split("=", 2)
          @isupport[key] = value
        else
          @isupport[param] = true
        end
      end
    end

    def handle_err_nicknameinuse(_message)
      @nick_attempts += 1
      new_nick = "#{@nick.sub(/_+$/, "")}#{"_" * @nick_attempts}"
      @nick = new_nick
      @socket.write(Registration.nick_message(@nick).to_s)
    end

    def handle_ping(message)
      token = message.params[0]
      pong = Message.new(command: "PONG", params: [token])
      @socket.write(pong.to_s)
    end

    def emit_events(message)
      emit(:raw, message, message: message)

      event_type = determine_event_type(message)
      return unless event_type

      attributes = build_event_attributes(event_type, message)
      emit(event_type, message, **attributes)
    end

    def emit(event_type, message, **attributes)
      handlers = @handlers[event_type]
      return unless handlers

      event = Event.new(type: event_type, message: message, **attributes)
      handlers.each do |handler|
        handler.call(event)
      rescue => e
        warn "Event handler error: #{e.message}"
      end
    end

    def determine_event_type(message)
      return EVENT_MAP[message.command] if EVENT_MAP.key?(message.command)

      if message.command == "001"
        :connect
      elsif message.command == "332"
        :topic
      elsif message.command.match?(/\A[45]\d\d\z/)
        :error
      end
    end

    def build_event_attributes(event_type, message)
      case event_type
      when :connect
        {server: message.source&.raw}
      when :message, :notice
        {source: message.source, target: message.params[0], text: message.params[1]}
      when :join
        {channel: message.params[0], user: message.source}
      when :part
        {channel: message.params[0], user: message.source, reason: message.params[1]}
      when :quit
        {user: message.source, reason: message.params[0]}
      when :kick
        {channel: message.params[0], user: message.params[1], by: message.source, reason: message.params[2]}
      when :nick
        {old_nick: message.source&.nick, new_nick: message.params[0]}
      when :topic
        if message.command == "332"
          {channel: message.params[1], topic: message.params[2], setter: nil}
        else
          {channel: message.params[0], topic: message.params[1], setter: message.source}
        end
      when :mode
        {target: message.params[0], modes: message.params[1], args: message.params[2..]}
      when :error
        {numeric: message.command.to_i, message: message.params.last}
      else
        {}
      end
    end
  end
end
