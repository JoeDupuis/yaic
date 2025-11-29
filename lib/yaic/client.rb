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

    PREFIX_MODES = {
      "@" => :op,
      "+" => :voice,
      "%" => :halfop,
      "~" => :owner,
      "&" => :admin
    }.freeze

    attr_reader :state, :isupport, :last_received_at, :channels

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
      @channels = {}
      @pending_names = {}
      @pending_whois = {}
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
      when "JOIN"
        handle_join(message)
      when "PART"
        handle_part(message)
      when "NICK"
        handle_nick(message)
      when "KICK"
        handle_kick(message)
      when "TOPIC"
        handle_topic(message)
      when "332"
        handle_rpl_topic(message)
      when "333"
        handle_rpl_topicwhotime(message)
      when "353"
        handle_rpl_namreply(message)
      when "366"
        handle_rpl_endofnames(message)
      when "MODE"
        handle_mode(message)
      when "352"
        handle_rpl_whoreply(message)
      when "311"
        handle_rpl_whoisuser(message)
      when "319"
        handle_rpl_whoischannels(message)
      when "312"
        handle_rpl_whoisserver(message)
      when "317"
        handle_rpl_whoisidle(message)
      when "330"
        handle_rpl_whoisaccount(message)
      when "301"
        handle_rpl_away(message)
      when "318"
        handle_rpl_endofwhois(message)
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

    def join(channel, key = nil)
      params = key ? [channel, key] : [channel]
      message = Message.new(command: "JOIN", params: params)
      @socket.write(message.to_s)
    end

    def part(channel, reason = nil)
      params = reason ? [channel, reason] : [channel]
      message = Message.new(command: "PART", params: params)
      @socket.write(message.to_s)
    end

    def quit(reason = nil)
      params = reason ? [reason] : []
      message = Message.new(command: "QUIT", params: params)
      @socket.write(message.to_s)
      @channels.clear
      @socket&.disconnect
      @state = :disconnected
      emit(:disconnect, nil)
    end

    def nick(new_nick = nil)
      return @nick if new_nick.nil?

      message = Message.new(command: "NICK", params: [new_nick])
      @socket.write(message.to_s)
    end

    def topic(channel, new_topic = nil)
      params = new_topic.nil? ? [channel] : [channel, new_topic]
      message = Message.new(command: "TOPIC", params: params)
      @socket.write(message.to_s)
    end

    def kick(channel, nick, reason = nil)
      params = reason ? [channel, nick, reason] : [channel, nick]
      message = Message.new(command: "KICK", params: params)
      @socket.write(message.to_s)
    end

    def names(channel)
      message = Message.new(command: "NAMES", params: [channel])
      @socket.write(message.to_s)
    end

    def mode(target, modes = nil, *args)
      params = [target]
      params << modes if modes
      params.concat(args) unless args.empty?
      message = Message.new(command: "MODE", params: params)
      @socket.write(message.to_s)
    end

    def who(mask)
      message = Message.new(command: "WHO", params: [mask])
      @socket.write(message.to_s)
    end

    def whois(nick)
      message = Message.new(command: "WHOIS", params: [nick])
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
      return unless @state == :registering

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

    def handle_join(message)
      channel_name = message.params[0]
      joiner_nick = message.source&.nick
      return unless joiner_nick && channel_name

      if joiner_nick == @nick
        @channels[channel_name] = Channel.new(channel_name)
      end
    end

    def handle_part(message)
      channel_name = message.params[0]
      parter_nick = message.source&.nick
      return unless parter_nick && channel_name

      if parter_nick == @nick
        @channels.delete(channel_name)
      end
    end

    def handle_nick(message)
      old_nick = message.source&.nick
      new_nick = message.params[0]
      return unless old_nick && new_nick

      if old_nick == @nick
        @nick = new_nick
      end

      @channels.each_value do |channel|
        if channel.users.key?(old_nick)
          user_data = channel.users.delete(old_nick)
          channel.users[new_nick] = user_data
        end
      end
    end

    def handle_kick(message)
      channel_name = message.params[0]
      kicked_nick = message.params[1]
      return unless channel_name && kicked_nick

      if kicked_nick == @nick
        @channels.delete(channel_name)
      else
        channel = @channels[channel_name]
        channel&.users&.delete(kicked_nick)
      end
    end

    def handle_topic(message)
      channel_name = message.params[0]
      topic_text = message.params[1]
      setter_nick = message.source&.nick
      return unless channel_name

      channel = @channels[channel_name]
      channel&.set_topic(topic_text, setter_nick)
    end

    def handle_rpl_topic(message)
      channel_name = message.params[1]
      topic_text = message.params[2]
      return unless channel_name

      channel = @channels[channel_name]
      channel&.set_topic(topic_text)
    end

    def handle_rpl_topicwhotime(message)
      channel_name = message.params[1]
      setter = message.params[2]
      time_str = message.params[3]
      return unless channel_name && setter && time_str

      channel = @channels[channel_name]
      channel&.set_topic(channel&.topic, setter, Time.at(time_str.to_i))
    end

    def handle_rpl_namreply(message)
      channel_name = message.params[2]
      users_str = message.params[3]
      return unless channel_name && users_str

      @pending_names[channel_name] ||= {}

      users_str.split.each do |user_entry|
        nick, modes = parse_user_with_prefix(user_entry)
        @pending_names[channel_name][nick] = modes
      end
    end

    def handle_rpl_endofnames(message)
      channel_name = message.params[1]
      return unless channel_name

      channel = @channels[channel_name]
      pending = @pending_names.delete(channel_name) || {}

      if channel
        pending.each do |nick, modes|
          channel.users[nick] = modes
        end
      end

      emit(:names, message, channel: channel_name, users: pending)
    end

    def handle_mode(message)
      target = message.params[0]
      return unless target

      modes_str = message.params[1]
      return unless modes_str

      channel = @channels[target]
      return unless channel

      params = message.params[2..] || []
      param_idx = 0

      adding = true
      modes_str.each_char do |char|
        case char
        when "+"
          adding = true
        when "-"
          adding = false
        when "o", "v", "h", "a", "q"
          nick = params[param_idx]
          param_idx += 1
          apply_user_mode(channel, nick, char, adding) if nick
        when "k"
          if adding
            channel.modes[:key] = params[param_idx]
            param_idx += 1
          else
            channel.modes.delete(:key)
          end
        when "l"
          if adding
            channel.modes[:limit] = params[param_idx].to_i
            param_idx += 1
          else
            channel.modes.delete(:limit)
          end
        when "m"
          channel.modes[:moderated] = adding ? true : nil
          channel.modes.delete(:moderated) unless adding
        when "i"
          channel.modes[:invite_only] = adding ? true : nil
          channel.modes.delete(:invite_only) unless adding
        when "t"
          channel.modes[:topic_protected] = adding ? true : nil
          channel.modes.delete(:topic_protected) unless adding
        when "n"
          channel.modes[:no_external] = adding ? true : nil
          channel.modes.delete(:no_external) unless adding
        when "s"
          channel.modes[:secret] = adding ? true : nil
          channel.modes.delete(:secret) unless adding
        when "p"
          channel.modes[:private] = adding ? true : nil
          channel.modes.delete(:private) unless adding
        when "b"
          param_idx += 1
        end
      end
    end

    def handle_rpl_whoreply(message)
      channel = message.params[1]
      user = message.params[2]
      host = message.params[3]
      server = message.params[4]
      nick = message.params[5]
      flags = message.params[6]
      hopcount_realname = message.params[7]

      away = flags&.include?("G") || false
      realname = hopcount_realname&.sub(/^\d+\s*/, "") || ""

      emit(:who, message, channel: channel, user: user, host: host, server: server,
        nick: nick, away: away, realname: realname)
    end

    def handle_rpl_whoisuser(message)
      nick = message.params[1]
      user = message.params[2]
      host = message.params[3]
      realname = message.params[5]

      @pending_whois[nick] = WhoisResult.new(nick: nick)
      @pending_whois[nick].user = user
      @pending_whois[nick].host = host
      @pending_whois[nick].realname = realname
    end

    def handle_rpl_whoischannels(message)
      nick = message.params[1]
      channels_str = message.params[2]
      return unless @pending_whois[nick] && channels_str

      channels_str.split.each do |chan|
        channel = chan.gsub(/^[@+%~&]+/, "")
        @pending_whois[nick].channels << channel
      end
    end

    def handle_rpl_whoisserver(message)
      nick = message.params[1]
      server = message.params[2]
      return unless @pending_whois[nick]

      @pending_whois[nick].server = server
    end

    def handle_rpl_whoisidle(message)
      nick = message.params[1]
      idle = message.params[2]&.to_i
      signon = message.params[3]&.to_i
      return unless @pending_whois[nick]

      @pending_whois[nick].idle = idle
      @pending_whois[nick].signon = signon ? Time.at(signon) : nil
    end

    def handle_rpl_whoisaccount(message)
      nick = message.params[1]
      account = message.params[2]
      return unless @pending_whois[nick]

      @pending_whois[nick].account = account
    end

    def handle_rpl_away(message)
      nick = message.params[1]
      away_msg = message.params[2]
      return unless @pending_whois[nick]

      @pending_whois[nick].away = away_msg
    end

    def handle_rpl_endofwhois(message)
      nick = message.params[1]
      result = @pending_whois.delete(nick)
      emit(:whois, message, result: result)
    end

    def apply_user_mode(channel, nick, mode_char, adding)
      return unless channel.users.key?(nick)

      mode_sym = case mode_char
      when "o" then :op
      when "v" then :voice
      when "h" then :halfop
      when "a" then :admin
      when "q" then :owner
      end
      return unless mode_sym

      if adding
        channel.users[nick] << mode_sym
      else
        channel.users[nick].delete(mode_sym)
      end
    end

    def parse_user_with_prefix(user_entry)
      modes = Set.new
      nick = user_entry

      while nick.length > 0 && PREFIX_MODES.key?(nick[0])
        modes << PREFIX_MODES[nick[0]]
        nick = nick[1..]
      end

      [nick, modes]
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
