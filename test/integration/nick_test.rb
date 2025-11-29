# frozen_string_literal: true

require "test_helper"

class NickIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_change_own_nick
    client = create_connected_client(@test_nick)

    new_nick = "new#{Process.pid}#{Time.now.to_i % 10000}"
    client.nick(new_nick)

    assert_equal new_nick, client.nick
  ensure
    client&.quit
  end

  def test_nick_in_use
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    error_received = false
    client2.on(:error) { |event| error_received = true if event.numeric == 433 }

    socket = client2.instance_variable_get(:@socket)
    msg = Yaic::Message.new(command: "NICK", params: [@test_nick])
    socket.write(msg.to_s)
    sleep 0.5

    assert error_received
    assert_equal @test_nick2, client2.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_invalid_nick
    client = create_connected_client(@test_nick)

    error_received = false
    client.on(:error) { |event| error_received = true if event.numeric == 432 }

    socket = client.instance_variable_get(:@socket)
    msg = Yaic::Message.new(command: "NICK", params: ["#invalid"])
    socket.write(msg.to_s)
    sleep 0.5

    assert error_received
    assert_equal @test_nick, client.nick
  ensure
    client&.quit
  end

  def test_other_user_changes_nick
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    nick_event = nil
    client1.on(:nick) { |event| nick_event = event if event.old_nick == @test_nick2 }

    new_nick = "r#{Process.pid}#{Time.now.to_i % 10000}"
    client2.nick(new_nick)
    sleep 0.5

    refute_nil nick_event
    assert_equal :nick, nick_event.type
    assert_equal @test_nick2, nick_event.old_nick
    assert_equal new_nick, nick_event.new_nick
  ensure
    client1&.quit
    client2&.quit
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end

  def create_connected_client(nick)
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: nick,
      user: "testuser",
      realname: "Test User"
    )
    client.connect
    client
  end
end
