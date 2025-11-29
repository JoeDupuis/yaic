# frozen_string_literal: true

require "test_helper"
require "timeout"

class PingPongIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_respond_to_ping_when_connected
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER testuser 0 * :Test User")

    read_until_welcome(socket)

    socket.write("PING :mytoken123")

    messages = read_until_pong(socket)
    pong = messages.find { |m| m.command == "PONG" }

    refute_nil pong, "Should receive PONG response"
    assert_includes pong.params, "mytoken123"
  ensure
    socket&.disconnect
  end

  def test_respond_to_server_ping_during_registration
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")

    messages = read_multiple(socket, 3)
    ping_received = messages.find { |m| m.command == "PING" }

    if ping_received
      token = ping_received.params[0]
      socket.write("PONG #{token}")
    end

    socket.write("USER testuser 0 * :Test User")

    messages = read_until_welcome(socket)
    welcome = messages.find { |m| m.command == "001" }

    refute_nil welcome, "Should receive RPL_WELCOME after PONG during registration"
  ensure
    socket&.disconnect
  end

  def test_handle_ping_without_colon
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER testuser 0 * :Test User")

    read_until_welcome(socket)

    socket.write("PING simpletoken")

    messages = read_until_pong(socket)
    pong = messages.find { |m| m.command == "PONG" }

    refute_nil pong, "Should receive PONG response"
    assert_includes pong.params, "simpletoken"
  ensure
    socket&.disconnect
  end

  def test_client_automatically_responds_to_server_ping
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    client.connect
    assert client.connected?

    initial_last_received = client.last_received_at
    sleep 6

    assert client.last_received_at > initial_last_received, "Client should continue receiving messages (PING handled)"
    refute client.connection_stale?
  ensure
    client&.quit
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

  def read_until_pong(socket, seconds = 5)
    messages = []
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          if msg
            messages << msg
            return messages if msg.command == "PONG"
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
