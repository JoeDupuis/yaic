# frozen_string_literal: true

require "test_helper"

class PingPongIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
  end

  def test_respond_to_ping_when_connected
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER testuser 0 * :Test User")

    wait_until(timeout: 10) do
      raw = socket.read
      raw && Yaic::Message.parse(raw)&.command == "001"
    end

    socket.write("PING :mytoken123")

    pong = nil
    wait_until(timeout: 5) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        pong = msg if msg&.command == "PONG"
      end
      pong
    end

    refute_nil pong, "Should receive PONG response"
    assert_includes pong.params, "mytoken123"
  ensure
    socket&.disconnect
  end

  def test_respond_to_server_ping_during_registration
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")

    ping_received = nil
    wait_until(timeout: 3) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        ping_received = msg if msg&.command == "PING"
      end
      ping_received
    end

    if ping_received
      token = ping_received.params[0]
      socket.write("PONG #{token}")
    end

    socket.write("USER testuser 0 * :Test User")

    welcome = nil
    wait_until(timeout: 10) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        welcome = msg if msg&.command == "001"
      end
      welcome
    end

    refute_nil welcome, "Should receive RPL_WELCOME after PONG during registration"
  ensure
    socket&.disconnect
  end

  def test_handle_ping_without_colon
    socket = Yaic::Socket.new(@host, @port)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER testuser 0 * :Test User")

    wait_until(timeout: 10) do
      raw = socket.read
      raw && Yaic::Message.parse(raw)&.command == "001"
    end

    socket.write("PING simpletoken")

    pong = nil
    wait_until(timeout: 5) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        pong = msg if msg&.command == "PONG"
      end
      pong
    end

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
    wait_until(timeout: 5) { client.last_received_at > initial_last_received }

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
end
