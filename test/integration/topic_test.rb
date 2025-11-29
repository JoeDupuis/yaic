# frozen_string_literal: true

require "test_helper"
require "timeout"

class TopicIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_get_topic
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    socket.write("TOPIC #{@test_channel} :Test Topic Text")
    wait_for_topic_set(socket)

    client.topic(@test_channel)

    topic_received = false
    topic_text = nil

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "332"
            topic_received = true
            topic_text = msg.params[2]
            break
          end
        end
        sleep 0.01
      end
    end

    assert topic_received, "Should receive RPL_TOPIC (332)"
    assert_equal "Test Topic Text", topic_text
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_get_topic_when_none_set
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    unique_channel = "#notopic#{Process.pid}#{Time.now.to_i}"
    client.join(unique_channel)
    wait_for_join(client, socket, unique_channel)

    client.topic(unique_channel)

    notopic_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "331"
            notopic_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert notopic_received, "Should receive RPL_NOTOPIC (331)"
  ensure
    socket&.write("PART #{unique_channel}")
    client&.disconnect
  end

  def test_set_topic
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    client.topic(@test_channel, "New topic from test")

    topic_confirmed = false
    new_topic = nil

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "TOPIC"
            topic_confirmed = true
            new_topic = msg.params[1]
            break
          end
        end
        sleep 0.01
      end
    end

    assert topic_confirmed, "Should receive TOPIC confirmation"
    assert_equal "New topic from test", new_topic
    assert_equal "New topic from test", client.channels[@test_channel].topic
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_clear_topic
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    socket.write("TOPIC #{@test_channel} :Topic to clear")
    wait_for_topic_set(socket)

    client.topic(@test_channel, "")

    topic_cleared = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "TOPIC"
            topic_cleared = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert topic_cleared, "Topic should be cleared"
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_set_topic_without_permission
    skip "InspIRCd 4 doesn't auto-op channel creators. Test requires ops to set +t mode. See 10-topic.md for details."
  end

  def test_receive_topic_change
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket2)

    topic_event = nil
    client2.on(:topic) { |event| topic_event = event }

    socket1.write("TOPIC #{@test_channel} :Changed by other user")

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if topic_event
        end
        sleep 0.01
      end
    end

    refute_nil topic_event
    assert_equal :topic, topic_event.type
    assert_equal @test_channel, topic_event.channel
    assert_equal "Changed by other user", topic_event.topic
    assert_equal @test_nick, topic_event.setter.nick
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
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

  def wait_for_topic_set(socket)
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw&.include?("TOPIC") || raw&.include?("332")
        sleep 0.01
      end
    end
  end

  def drain_messages(socket)
    loop do
      raw = socket.read
      break if raw.nil?
    end
  end
end
