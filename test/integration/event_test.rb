# frozen_string_literal: true

require "test_helper"

class EventIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
    @test_nick2 = unique_nick("u")
    @test_channel = unique_channel("#evt")
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

    refute_nil connect_event, "Should receive :connect event"
    assert_equal :connect, connect_event.type
    refute_nil connect_event.server, "Connect event should have server attribute"
  ensure
    client&.quit
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
    client.join(@test_channel)

    refute_nil join_event, "Should receive :join event"
    assert_equal :join, join_event.type
    assert_equal @test_channel, join_event.channel
    assert_equal @test_nick, join_event.user.nick
  ensure
    client&.quit
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
    client2.connect

    client2.privmsg(@test_nick, "hello from test")
    sleep 0.5

    refute_nil message_event, "Should receive :message event"
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_nick, message_event.target
    assert_equal "hello from test", message_event.text
  ensure
    client1&.quit
    client2&.quit
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
    raw_events.clear

    client.join(@test_channel)

    refute_nil join_event, "Should receive :join event"
    assert raw_events.any? { |e| e.message.command == "JOIN" }, "Should receive :raw event for JOIN"
  ensure
    client&.quit
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end
end
