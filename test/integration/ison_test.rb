# frozen_string_literal: true

require "test_helper"

class IsonIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
    @test_nick2 = unique_nick("u")
  end

  def test_ison_returns_online_nicks
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    results = client1.ison(@test_nick2)

    assert_instance_of Array, results
    assert_equal 1, results.size
    assert_equal @test_nick2, results.first
  ensure
    client1&.quit
    client2&.quit
  end

  def test_ison_returns_multiple_online_nicks
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    results = client1.ison(@test_nick, @test_nick2)

    assert_instance_of Array, results
    assert_equal 2, results.size
    assert_includes results, @test_nick
    assert_includes results, @test_nick2
  ensure
    client1&.quit
    client2&.quit
  end

  def test_ison_returns_empty_for_offline_nicks
    client = create_connected_client(@test_nick)

    results = client.ison("nobody_exists_here", "also_not_here")

    assert_instance_of Array, results
    assert_empty results
  ensure
    client&.quit
  end

  def test_ison_filters_offline_from_online
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    results = client1.ison(@test_nick2, "nobody_exists_here")

    assert_instance_of Array, results
    assert_equal 1, results.size
    assert_includes results, @test_nick2
    refute_includes results, "nobody_exists_here"
  ensure
    client1&.quit
    client2&.quit
  end

  def test_ison_emits_event
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    ison_event = nil
    client1.on(:ison) { |event| ison_event = event }

    results = client1.ison(@test_nick2)

    refute_nil results
    refute_nil ison_event
    assert_equal :ison, ison_event.type
    assert_includes ison_event.nicks, @test_nick2
  ensure
    client1&.quit
    client2&.quit
  end

  def test_ison_with_array_argument
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    results = client1.ison([@test_nick, @test_nick2])

    assert_instance_of Array, results
    assert_equal 2, results.size
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
