# frozen_string_literal: true

require "test_helper"
require "timeout"

class WhoWhoisIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_who_channel
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    who_replies = []
    client1.on(:who) { |event| who_replies << event }

    client1.who(@test_channel)

    end_of_who = false
    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          if msg&.command == "315"
            end_of_who = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert end_of_who, "Should receive RPL_ENDOFWHO"
    assert who_replies.size >= 2, "Should have at least 2 WHO replies"

    nicks = who_replies.map(&:nick)
    assert_includes nicks, @test_nick
    assert_includes nicks, @test_nick2
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_who_specific_nick
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    drain_messages(socket1)
    drain_messages(socket2)

    who_replies = []
    client1.on(:who) { |event| who_replies << event }

    client1.who(@test_nick2)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if msg&.command == "315"
        end
        sleep 0.01
      end
    end

    assert_equal 1, who_replies.size, "Should have exactly 1 WHO reply"
    assert_equal @test_nick2, who_replies.first.nick
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_who_non_existent
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    drain_messages(socket)

    who_replies = []
    client.on(:who) { |event| who_replies << event }

    client.who("nobody_exists_here")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if msg&.command == "315"
        end
        sleep 0.01
      end
    end

    assert_empty who_replies, "Should have no WHO replies for non-existent nick"
  ensure
    client&.disconnect
  end

  def test_whois_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    drain_messages(socket1)
    drain_messages(socket2)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if whois_event
        end
        sleep 0.01
      end
    end

    refute_nil whois_event, "Should receive WHOIS event"
    refute_nil whois_event.result, "Should have WHOIS result"
    assert_equal @test_nick2, whois_event.result.nick
    refute_nil whois_event.result.user
    refute_nil whois_event.result.host
    refute_nil whois_event.result.server
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_whois_with_channels
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if whois_event
        end
        sleep 0.01
      end
    end

    refute_nil whois_event.result
    assert_includes whois_event.result.channels, @test_channel
  ensure
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_whois_non_existent
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    drain_messages(socket)

    whois_event = nil
    error_event = nil
    client.on(:whois) { |event| whois_event = event }
    client.on(:error) { |event| error_event = event }

    client.whois("nobody_exists_here")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if whois_event
        end
        sleep 0.01
      end
    end

    refute_nil error_event, "Should receive error event for 401"
    assert_equal 401, error_event.numeric

    refute_nil whois_event, "Should receive WHOIS event even on error"
    assert_nil whois_event.result, "Result should be nil for non-existent nick"
  ensure
    client&.disconnect
  end

  def test_whois_away_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    socket2.write("AWAY :I am busy")
    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        break if raw&.include?("306")
        sleep 0.01
      end
    end

    drain_messages(socket1)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if whois_event
        end
        sleep 0.01
      end
    end

    refute_nil whois_event.result
    assert_equal "I am busy", whois_event.result.away
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
