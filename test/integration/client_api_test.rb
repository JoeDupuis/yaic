# frozen_string_literal: true

require "test_helper"

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

    refute_nil connect_event, "Should receive :connect event"
    assert client.connected?, "client.connected? should be true"
    assert_equal @host, client.server
  ensure
    client&.quit
  end

  def test_join_channel_and_send_message
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    received_message = nil
    client2.on(:message) { |event| received_message = event }

    client1.privmsg(@test_channel, "Hello from API test")

    sleep 0.5

    refute_nil received_message, "Should receive :message event"
    assert_equal "Hello from API test", received_message.text
    assert_equal @test_nick, received_message.source.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_receive_and_handle_message
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    messages = []
    client1.on(:message) { |event| messages << event }

    client1.join(@test_channel)
    client2.join(@test_channel)

    client2.privmsg(@test_channel, "Hello!")

    sleep 0.5

    refute_empty messages
    assert_equal "Hello!", messages.first.text
    assert_equal @test_nick2, messages.first.source.nick
    assert_equal @test_channel, messages.first.target
  ensure
    client1&.quit
    client2&.quit
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

    assert client.connected?
    assert_equal :connected, client.state
    assert_equal @test_nick, client.nick

    client.join(@test_channel)
    assert client.channels.key?(@test_channel)

    client.part(@test_channel, "Testing part")
    sleep 0.5
    refute client.channels.key?(@test_channel)

    client.quit("Session complete")

    refute client.connected?
    assert_equal :disconnected, client.state

    assert_equal 1, events.count { |type, _event| type == :connect }
    assert_equal 1, events.count { |type, _event| type == :join }
    assert_equal 1, events.count { |type, _event| type == :disconnect }
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
    client = create_connected_client(@test_nick)

    error_events = []
    client.on(:error) { |event| error_events << event }

    client.privmsg("nonexistent_user_#{rand(10000)}", "Hello")

    sleep 0.5

    assert error_events.any? { |e| e.numeric == 401 }, "Should receive ERR_NOSUCHNICK (401)"
  ensure
    client&.quit
  end

  private

  def require_server_available
    TCPSocket.new(@host, @port).close
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
