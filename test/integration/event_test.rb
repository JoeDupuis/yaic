# frozen_string_literal: true

require "test_helper"
require "timeout"

class EventIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_connect_event_on_successful_registration
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    connect_event = nil
    client.on(:connect) { |event| connect_event = event }

    client.connect
    client.on_socket_connected

    socket = client.instance_variable_get(:@socket)

    Timeout.timeout(10) do
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

    refute_nil connect_event, "Should receive :connect event"
    assert_equal :connect, connect_event.type
    refute_nil connect_event.server, "Connect event should have server attribute"
  ensure
    client&.disconnect
  end

  def test_join_event_when_joining_channel
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    join_event = nil
    client.on(:join) { |event| join_event = event }

    client.connect
    client.on_socket_connected

    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    socket.write("JOIN #testevt")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if join_event
        end
        sleep 0.01
      end
    end

    refute_nil join_event, "Should receive :join event"
    assert_equal :join, join_event.type
    assert_equal "#testevt", join_event.channel
    assert_equal @test_nick, join_event.user.nick
  ensure
    socket&.write("PART #testevt")
    client&.disconnect
  end

  def test_message_event_from_privmsg
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

    message_event = nil
    client1.on(:message) { |event| message_event = event }

    client1.connect
    client1.on_socket_connected
    socket1 = client1.instance_variable_get(:@socket)
    wait_for_connection(client1, socket1)

    client2.connect
    client2.on_socket_connected
    socket2 = client2.instance_variable_get(:@socket)
    wait_for_connection(client2, socket2)

    socket2.write("PRIVMSG #{@test_nick} :hello from test")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if message_event
        end
        sleep 0.01
      end
    end

    refute_nil message_event, "Should receive :message event"
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_nick, message_event.target
    assert_equal "hello from test", message_event.text
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_raw_and_typed_events_both_emitted
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User"
    )

    raw_events = []
    join_event = nil
    client.on(:raw) { |event| raw_events << event }
    client.on(:join) { |event| join_event = event }

    client.connect
    client.on_socket_connected

    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    raw_events.clear

    socket.write("JOIN #testevt2")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if join_event
        end
        sleep 0.01
      end
    end

    refute_nil join_event, "Should receive :join event"
    assert raw_events.any? { |e| e.message.command == "JOIN" }, "Should receive :raw event for JOIN"
  ensure
    socket&.write("PART #testevt2")
    client&.disconnect
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
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
end
