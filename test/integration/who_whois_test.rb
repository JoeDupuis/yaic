# frozen_string_literal: true

require "test_helper"

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
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    who_replies = []
    client1.on(:who) { |event| who_replies << event }

    client1.who(@test_channel)
    sleep 0.5

    assert who_replies.size >= 2, "Should have at least 2 WHO replies"

    nicks = who_replies.map(&:nick)
    assert_includes nicks, @test_nick
    assert_includes nicks, @test_nick2
  ensure
    client1&.quit
    client2&.quit
  end

  def test_who_specific_nick
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    who_replies = []
    client1.on(:who) { |event| who_replies << event }

    client1.who(@test_nick2)
    sleep 0.5

    assert_equal 1, who_replies.size, "Should have exactly 1 WHO reply"
    assert_equal @test_nick2, who_replies.first.nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_who_non_existent
    client = create_connected_client(@test_nick)

    who_replies = []
    client.on(:who) { |event| who_replies << event }

    client.who("nobody_exists_here")
    sleep 0.5

    assert_empty who_replies, "Should have no WHO replies for non-existent nick"
  ensure
    client&.quit
  end

  def test_whois_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)
    sleep 0.5

    refute_nil whois_event, "Should receive WHOIS event"
    refute_nil whois_event.result, "Should have WHOIS result"
    assert_equal @test_nick2, whois_event.result.nick
    refute_nil whois_event.result.user
    refute_nil whois_event.result.host
    refute_nil whois_event.result.server
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_with_channels
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client2.join(@test_channel)

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)
    sleep 0.5

    refute_nil whois_event.result
    assert_includes whois_event.result.channels, @test_channel
  ensure
    client1&.quit
    client2&.quit
  end

  def test_whois_non_existent
    client = create_connected_client(@test_nick)

    whois_event = nil
    error_event = nil
    client.on(:whois) { |event| whois_event = event }
    client.on(:error) { |event| error_event = event }

    client.whois("nobody_exists_here")
    sleep 0.5

    refute_nil error_event, "Should receive error event for 401"
    assert_equal 401, error_event.numeric

    refute_nil whois_event, "Should receive WHOIS event even on error"
    assert_nil whois_event.result, "Result should be nil for non-existent nick"
  ensure
    client&.quit
  end

  def test_whois_away_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client2.raw("AWAY :I am busy")
    sleep 0.5

    whois_event = nil
    client1.on(:whois) { |event| whois_event = event }

    client1.whois(@test_nick2)
    sleep 0.5

    refute_nil whois_event.result
    assert_equal "I am busy", whois_event.result.away
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
