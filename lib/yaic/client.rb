# frozen_string_literal: true

module Yaic
  class Client
    STALE_TIMEOUT = 180

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
    end

    def connection_stale?
      return false if @last_received_at.nil?
      Time.now - @last_received_at > STALE_TIMEOUT
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
  end
end
