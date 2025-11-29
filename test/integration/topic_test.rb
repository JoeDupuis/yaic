# frozen_string_literal: true

require "test_helper"

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
    client.join(@test_channel)

    client.topic(@test_channel, "Test Topic Text")
    sleep 0.5

    client.topic(@test_channel)

    topic_received = false
    topic_text = nil

    client.on(:raw) do |event|
      msg = event.message
      if msg.command == "332"
        topic_received = true
        topic_text = msg.params[2]
      end
    end

    sleep 0.5

    assert topic_received, "Should receive RPL_TOPIC (332)"
    assert_equal "Test Topic Text", topic_text
  ensure
    client&.quit
  end

  def test_get_topic_when_none_set
    client = create_connected_client(@test_nick)

    unique_channel = "#notopic#{Process.pid}#{Time.now.to_i}"
    client.join(unique_channel)

    notopic_received = false

    client.on(:raw) do |event|
      msg = event.message
      if msg.command == "331"
        notopic_received = true
      end
    end

    client.topic(unique_channel)

    sleep 0.5

    assert notopic_received, "Should receive RPL_NOTOPIC (331)"
  ensure
    client&.quit
  end

  def test_set_topic
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    topic_confirmed = false
    new_topic = nil

    client.on(:topic) do |event|
      topic_confirmed = true
      new_topic = event.topic
    end

    client.topic(@test_channel, "New topic from test")

    sleep 0.5

    assert topic_confirmed, "Should receive TOPIC confirmation"
    assert_equal "New topic from test", new_topic
    assert_equal "New topic from test", client.channels[@test_channel].topic
  ensure
    client&.quit
  end

  def test_clear_topic
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    client.topic(@test_channel, "Topic to clear")
    sleep 0.5

    topic_cleared = false

    client.on(:topic) do |event|
      topic_cleared = true
    end

    client.topic(@test_channel, "")

    sleep 0.5

    assert topic_cleared, "Topic should be cleared"
  ensure
    client&.quit
  end

  def test_set_topic_without_permission
    skip "InspIRCd 4 doesn't auto-op channel creators. Test requires ops to set +t mode. See 10-topic.md for details."
  end

  def test_receive_topic_change
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    sleep 0.5

    topic_event = nil
    client2.on(:topic) { |event| topic_event = event }

    client1.topic(@test_channel, "Changed by other user")

    sleep 0.5

    refute_nil topic_event
    assert_equal :topic, topic_event.type
    assert_equal @test_channel, topic_event.channel
    assert_equal "Changed by other user", topic_event.topic
    assert_equal @test_nick, topic_event.setter.nick
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
