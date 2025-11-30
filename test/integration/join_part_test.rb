# frozen_string_literal: true

require "test_helper"

class JoinPartIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
    @test_nick2 = unique_nick("u")
    @test_channel = unique_channel
  end

  def test_join_single_channel
    client = create_connected_client(@test_nick)

    client.join(@test_channel)

    assert client.channels.key?(@test_channel)
  ensure
    client&.quit
  end

  def test_join_channel_with_topic
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)
    topic_set = false
    client1.on(:topic) { topic_set = true }
    client1.topic(@test_channel, "Test Topic")
    wait_until { topic_set }

    client2 = create_connected_client(@test_nick2)
    topic_event = nil
    client2.on(:topic) { |e| topic_event = e }

    client2.join(@test_channel)
    wait_until { topic_event }

    refute_nil topic_event
    assert_equal "Test Topic", topic_event.topic
  ensure
    client1&.quit
    client2&.quit
  end

  def test_join_multiple_channels
    client = create_connected_client(@test_nick)

    chan_a = "#{@test_channel}a"
    chan_b = "#{@test_channel}b"
    chan_c = "#{@test_channel}c"

    message = Yaic::Message.new(command: "JOIN", params: ["#{chan_a},#{chan_b},#{chan_c}"])
    client.raw(message.to_s)
    wait_until { client.channels.key?(chan_a) && client.channels.key?(chan_b) && client.channels.key?(chan_c) }

    assert client.channels.key?(chan_a)
    assert client.channels.key?(chan_b)
    assert client.channels.key?(chan_c)
  ensure
    client&.quit
  end

  def test_join_creates_channel_if_not_exists
    client = create_connected_client(@test_nick)

    new_channel = unique_channel("#new")
    client.join(new_channel)

    assert client.channels.key?(new_channel)
  ensure
    client&.quit
  end

  def test_part_single_channel
    client = create_connected_client(@test_nick)
    client.join(@test_channel)
    assert client.channels.key?(@test_channel)

    client.part(@test_channel)
    refute client.channels.key?(@test_channel)
  ensure
    client&.quit
  end

  def test_part_with_reason
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    part_event = nil
    client.on(:part) { |e| part_event = e }

    client.part(@test_channel, "Going home")
    wait_until { part_event }

    refute_nil part_event
    assert_equal @test_channel, part_event.channel
  ensure
    client&.quit
  end

  def test_part_channel_not_in_receives_error
    client = create_connected_client(@test_nick)

    error_event = nil
    client.on(:error) { |e| error_event = e if [403, 442].include?(e.numeric) }

    message = Yaic::Message.new(command: "PART", params: [unique_channel("#notin")])
    client.raw(message.to_s)
    wait_until { error_event }

    refute_nil error_event
    assert_includes [403, 442], error_event.numeric
  ensure
    client&.quit
  end

  def test_join_event_on_self_join
    client = create_connected_client(@test_nick)

    join_event = nil
    client.on(:join) { |e| join_event = e if e.user.nick == @test_nick }

    client.join(@test_channel)

    refute_nil join_event
    assert_equal :join, join_event.type
    assert_equal @test_channel, join_event.channel
    assert_equal @test_nick, join_event.user.nick
  ensure
    client&.quit
  end

  def test_join_event_on_other_join
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    other_join_event = nil
    client1.on(:join) { |e| other_join_event = e if e.user.nick == @test_nick2 }

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)
    wait_until { other_join_event }

    refute_nil other_join_event
    assert_equal :join, other_join_event.type
    assert_equal @test_channel, other_join_event.channel
    assert_equal @test_nick2, other_join_event.user.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_part_event_on_self_part
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    part_event = nil
    client.on(:part) { |e| part_event = e }

    client.part(@test_channel)

    refute_nil part_event
    assert_equal :part, part_event.type
    assert_equal @test_channel, part_event.channel
    assert_equal @test_nick, part_event.user.nick
  ensure
    client&.quit
  end

  def test_part_event_on_other_part
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    client2 = create_connected_client(@test_nick2)
    client2_joined = false
    client1.on(:join) { |e| client2_joined = true if e.user.nick == @test_nick2 }
    client2.join(@test_channel)
    wait_until { client2_joined }

    other_part_event = nil
    client1.on(:part) { |e| other_part_event = e if e.user.nick == @test_nick2 }

    client2.part(@test_channel)
    wait_until { other_part_event }

    refute_nil other_part_event
    assert_equal :part, other_part_event.type
    assert_equal @test_channel, other_part_event.channel
    assert_equal @test_nick2, other_part_event.user.nick
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
