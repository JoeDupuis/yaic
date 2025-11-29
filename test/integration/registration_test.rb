# frozen_string_literal: true

require "test_helper"
require "timeout"

class RegistrationIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_register_with_nickname_and_user
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER testuser 0 * :Test User")

    messages = read_until_welcome(socket)

    welcome = messages.find { |m| m.command == "001" }
    refute_nil welcome, "Should receive RPL_WELCOME (001)"
  ensure
    socket&.disconnect
  end

  def test_nick_already_in_use
    nick = "dup#{Process.pid}#{rand(1000)}"

    socket1 = Yaic::Socket.new(@host, @port)
    socket1.connect
    socket1.write("NICK #{nick}")
    socket1.write("USER user1 0 * :User One")
    read_until_welcome(socket1)

    socket2 = Yaic::Socket.new(@host, @port)
    socket2.connect
    socket2.write("NICK #{nick}")
    socket2.write("USER user2 0 * :User Two")

    messages = read_multiple(socket2, 5)

    nick_in_use = messages.find { |m| m.command == "433" }
    refute_nil nick_in_use, "Should receive ERR_NICKNAMEINUSE (433)"
  ensure
    socket1&.disconnect
    socket2&.disconnect
  end

  def test_invalid_nickname
    socket = Yaic::Socket.new(@host, @port)
    socket.connect
    socket.write("NICK #invalid")

    messages = read_multiple(socket, 5)

    erroneous = messages.find { |m| m.command == "432" }
    refute_nil erroneous, "Should receive ERR_ERRONEUSNICKNAME (432)"
  ensure
    socket&.disconnect
  end

  def test_empty_nickname
    socket = Yaic::Socket.new(@host, @port)
    socket.connect
    socket.write("NICK")

    messages = read_multiple(socket, 5)

    error = messages.find { |m| m.command == "431" || m.command == "461" }
    refute_nil error, "Should receive ERR_NONICKNAMEGIVEN (431) or ERR_NEEDMOREPARAMS (461)"
  ensure
    socket&.disconnect
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end

  def read_until_welcome(socket, seconds = 10)
    messages = []
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          if msg
            messages << msg
            return messages if msg.command == "001"
          end
        end
        sleep 0.01
      end
    end
  rescue Timeout::Error
    messages
  end

  def read_multiple(socket, seconds)
    messages = []
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          messages << msg if msg
        end
        sleep 0.01
      end
    end
  rescue Timeout::Error
    messages
  end
end
