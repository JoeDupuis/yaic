# frozen_string_literal: true

require "test_helper"

class WhoWhoisIntegrationTest < Minitest::Test
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

  def test_who_channel_returns_all_users
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    results = client1.who(@test_channel)

    assert_instance_of Array, results
    assert results.size >= 2, "Should have at least 2 WHO results"

    nicks = results.map(&:nick)
    assert_includes nicks, @test_nick
    assert_includes nicks, @test_nick2

    result = results.find { |r| r.nick == @test_nick }
    assert_instance_of Yaic::WhoResult, result
    refute_nil result.user
    refute_nil result.host
    refute_nil result.server
    assert_equal @test_channel, result.channel
    assert_equal false, result.away
  ensure
    client1&.quit
    client2&.quit
  end

  def test_who_nick_returns_single_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    results = client1.who(@test_nick2)

    assert_equal 1, results.size, "Should have exactly 1 WHO result"
    assert_equal @test_nick2, results.first.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_who_non_existent_returns_empty_array
    client = create_connected_client(@test_nick)

    results = client.who("nobody_exists_here")

    assert_instance_of Array, results
    assert_empty results, "Should have no WHO results for non-existent nick"
  ensure
    client&.quit
  end

  def test_who_still_emits_events
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    who_events = []
    client1.on(:who) { |event| who_events << event }

    results = client1.who(@test_channel)

    assert results.size >= 2
    assert who_events.size >= 2
    assert_equal results.size, who_events.size
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_returns_user_info
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    result = client1.whois(@test_nick2)

    assert_instance_of Yaic::WhoisResult, result
    assert_equal @test_nick2, result.nick
    refute_nil result.user
    refute_nil result.host
    refute_nil result.server
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_with_channels
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client2.join(@test_channel)

    result = client1.whois(@test_nick2)

    refute_nil result
    assert_includes result.channels, @test_channel
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_unknown_returns_nil
    client = create_connected_client(@test_nick)

    result = client.whois("nobody_exists_here")

    assert_nil result, "Result should be nil for non-existent nick"
  ensure
    client&.quit
  end

  def test_whois_still_emits_events
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    result = client1.whois(@test_nick2)

    refute_nil result
    refute_nil whois_event
    assert_equal result.nick, whois_event.result.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_away_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    away_set = false
    client2.on(:raw) { |event| away_set = true if event.message&.command == "306" }
    client2.raw("AWAY :I am busy")
    wait_until { away_set }

    result = client1.whois(@test_nick2)

    refute_nil result
    assert_equal "I am busy", result.away
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
