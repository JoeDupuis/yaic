# frozen_string_literal: true

require "test_helper"
require "timeout"

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
