# frozen_string_literal: true

require "test_helper"

class RegistrationIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
  end

  def test_register_with_nickname_and_user
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    client.connect
    assert client.connected?
  ensure
    client&.quit
  end

  def test_nick_already_in_use
    nick = unique_nick("dup")

    client1 = Yaic::Client.new(host: @host, port: @port, nick: nick, user: "user1", realname: "User One")
    client1.connect

    client2 = Yaic::Client.new(host: @host, port: @port, nick: nick, user: "user2", realname: "User Two")
    client2.connect

    refute_equal nick, client2.nick
    assert client2.nick.start_with?(nick)
  ensure
    client1&.quit
    client2&.quit
  end

  def test_invalid_nickname
    socket = Yaic::Socket.new(@host, @port)
    socket.connect
    socket.write("NICK #invalid")

    erroneous = nil
    wait_until(timeout: 5) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        erroneous = msg if msg&.command == "432"
      end
      erroneous
    end

    refute_nil erroneous, "Should receive ERR_ERRONEUSNICKNAME (432)"
  ensure
    socket&.disconnect
  end

  def test_empty_nickname
    socket = Yaic::Socket.new(@host, @port)
    socket.connect
    socket.write("NICK")

    error = nil
    wait_until(timeout: 5) do
      raw = socket.read
      if raw
        msg = Yaic::Message.parse(raw)
        error = msg if msg&.command == "431" || msg&.command == "461"
      end
      error
    end

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
end
