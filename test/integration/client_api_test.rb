# frozen_string_literal: true

require "test_helper"
require "timeout"

class ClientApiIntegrationTest < Minitest::Test
  def setup
    @host = "localhost"
    @port = 6667
    require_server_available
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#api#{Process.pid}#{rand(1000)}"
  end

  def test_connect_and_receive_welcome
    client = Yaic::Client.new(
      server: @host,
      port: @port,
      nickname: @test_nick,
      username: "testuser",
      realname: "Test User"
    )

    connect_event = nil
    client.on(:connect) { |event| connect_event = event }

    client.connect
    client.on_socket_connected
    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    refute_nil connect_event, "Should receive :connect event"
    assert client.connected?, "client.connected? should be true"
    assert_equal @host, client.server
  ensure
    begin
      client&.quit
    rescue
      nil
    end
    client&.disconnect
  end

  def test_join_channel_and_send_message
    client1 = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    client2 = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick2,
      user: "testuser2",
      realname: "Test User 2"
    )

    client1.connect
    client1.on_socket_connected
    socket1 = client1.instance_variable_get(:@socket)
    wait_for_connection(client1, socket1)

    client2.connect
    client2.on_socket_connected
    socket2 = client2.instance_variable_get(:@socket)
    wait_for_connection(client2, socket2)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    received_message = nil
    client2.on(:message) { |event| received_message = event }

    client1.privmsg(@test_channel, "Hello from API test")

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if received_message
        end
        sleep 0.01
      end
    end

    refute_nil received_message, "Should receive :message event"
    assert_equal "Hello from API test", received_message.text
    assert_equal @test_nick, received_message.source.nick
  ensure
    begin
      client1&.quit
    rescue
      nil
    end
    client1&.disconnect
    begin
      client2&.quit
    rescue
      nil
    end
    client2&.disconnect
  end

  def test_receive_and_handle_message
    client1 = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick
    )

    client2 = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick2
    )

    messages = []
    client1.on(:message) { |event| messages << event }

    client1.connect
    client1.on_socket_connected
    socket1 = client1.instance_variable_get(:@socket)
    wait_for_connection(client1, socket1)

    client2.connect
    client2.on_socket_connected
    socket2 = client2.instance_variable_get(:@socket)
    wait_for_connection(client2, socket2)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    client2.privmsg(@test_channel, "Hello!")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if messages.any?
        end
        sleep 0.01
      end
    end

    refute_empty messages
    assert_equal "Hello!", messages.first.text
    assert_equal @test_nick2, messages.first.source.nick
    assert_equal @test_channel, messages.first.target
  ensure
    begin
      client1&.quit
    rescue
      nil
    end
    client1&.disconnect
    begin
      client2&.quit
    rescue
      nil
    end
    client2&.disconnect
  end

  def test_full_session_lifecycle
    client = Yaic::Client.new(
      server: @host,
      port: @port,
      nickname: @test_nick
    )

    events = []
    client.on(:connect) { |e| events << [:connect, e] }
    client.on(:join) { |e| events << [:join, e] }
    client.on(:disconnect) { |e| events << [:disconnect, e] }

    refute client.connected?
    assert_equal :disconnected, client.state

    client.connect
    client.on_socket_connected
    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    assert client.connected?
    assert_equal :connected, client.state
    assert_equal @test_nick, client.nick

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)
    assert client.channels.key?(@test_channel)

    client.part(@test_channel, "Testing part")
    wait_for_part(client, socket, @test_channel)
    refute client.channels.key?(@test_channel)

    client.quit("Session complete")

    refute client.connected?
    assert_equal :disconnected, client.state

    assert_equal 1, events.count { |type, _event| type == :connect }
    assert_equal 1, events.count { |type, _event| type == :join }
    assert_equal 1, events.count { |type, _event| type == :disconnect }
  ensure
    client&.disconnect
  end

  def test_connection_refused_raises_error
    client = Yaic::Client.new(
      server: "127.0.0.1",
      port: 65432,
      nickname: "test"
    )

    assert_raises(Errno::ECONNREFUSED) do
      client.connect
    end
  end

  def test_server_error_numeric_triggers_error_event
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick
    )

    error_events = []
    client.on(:error) { |event| error_events << event }

    client.connect
    client.on_socket_connected
    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    client.privmsg("nonexistent_user_#{rand(10000)}", "Hello")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if error_events.any? { |e| e.numeric == 401 }
        end
        sleep 0.01
      end
    end

    assert error_events.any? { |e| e.numeric == 401 }, "Should receive ERR_NOSUCHNICK (401)"
  ensure
    begin
      client&.quit
    rescue
      nil
    end
    client&.disconnect
  end

  private

  def require_server_available
    TCPSocket.new(@host, @port).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
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
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if client.channels.key?(channel)
        end
        sleep 0.01
      end
    end
  end

  def wait_for_part(client, socket, channel, seconds = 5)
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break unless client.channels.key?(channel)
        end
        sleep 0.01
      end
    end
  end
end
