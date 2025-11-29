# frozen_string_literal: true

require "test_helper"
require "timeout"

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
    socket = client.instance_variable_get(:@socket)

    new_nick = "new#{Process.pid}#{Time.now.to_i % 10000}"
    client.nick(new_nick)

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if msg&.command == "NICK" && msg&.params&.first == new_nick
        end
        sleep 0.01
      end
    end

    assert_equal new_nick, client.nick
  ensure
    client&.disconnect
  end

  def test_nick_in_use
    client1 = create_connected_client(@test_nick)
    client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    error_received = false
    client2.on(:error) do |event|
      error_received = true if event.numeric == 433
    end

    client2.nick(@test_nick)

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if error_received || msg&.command == "433"
        end
        sleep 0.01
      end
    end

    assert error_received
    assert_equal @test_nick2, client2.nick
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_invalid_nick
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    error_received = false
    client.on(:error) do |event|
      error_received = true if event.numeric == 432
    end

    client.nick("#invalid")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if error_received || msg&.command == "432"
        end
        sleep 0.01
      end
    end

    assert error_received
    assert_equal @test_nick, client.nick
  ensure
    client&.disconnect
  end

  def test_other_user_changes_nick
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)
    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    nick_event = nil
    client1.on(:nick) do |event|
      nick_event = event if event.old_nick == @test_nick2
    end

    new_nick = "r#{Process.pid}#{Time.now.to_i % 10000}"
    client2.nick(new_nick)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if nick_event
        end
        sleep 0.01
      end
    end

    refute_nil nick_event
    assert_equal :nick, nick_event.type
    assert_equal @test_nick2, nick_event.old_nick
    assert_equal new_nick, nick_event.new_nick
  ensure
    client1&.disconnect
    client2&.disconnect
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
    client.on_socket_connected

    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    client
  end

  def wait_for_connection(client, socket, seconds = 10)
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if client.state == :connected
        end
        sleep 0.01
      end
    end
  end

  def wait_for_join(client, socket, channel, seconds = 5)
    joined = false
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "JOIN" && msg&.params&.first == channel
            joined = true
          end
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end
    joined
  end

  def drain_messages(socket)
    loop do
      raw = socket.read
      break if raw.nil?
    end
  end
end
