# frozen_string_literal: true

require "test_helper"

class NamesIntegrationTest < Minitest::Test
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

  def test_get_names
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    names_event = nil
    client.on(:names) { |event| names_event = event }

    client.names(@test_channel)
    wait_until { names_event }

    refute_nil names_event
    channel = client.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have self in user list"
  ensure
    client&.quit
  end

  def test_names_with_prefixes
    client1 = create_connected_client(@test_nick)

    become_oper(client1)

    client1.join(@test_channel)

    client1.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(client1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    names_event = nil
    client2.on(:names) { |event| names_event = event }

    client2.names(@test_channel)
    wait_until { names_event }

    refute_nil names_event
    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick)
    assert_includes channel.users[@test_nick], :op
  ensure
    client1&.quit
    client2&.quit
  end

  def test_names_at_join
    client1 = create_connected_client(@test_nick)

    become_oper(client1)

    client1.join(@test_channel)

    client1.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(client1, @test_channel)

    client2 = create_connected_client(@test_nick2)

    names_event = nil
    client2.on(:names) { |event| names_event = event }

    client2.join(@test_channel)

    refute_nil names_event
    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have first user in list"
    assert channel.users.key?(@test_nick2), "Should have self in list"
    assert_includes channel.users[@test_nick], :op
  ensure
    client1&.quit
    client2&.quit
  end

  def test_multi_message_names
    client = create_connected_client(@test_nick)

    become_oper(client)

    client.join(@test_channel)

    client.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(client, @test_channel)

    clients = []
    4.times do |i|
      nick = unique_nick("x#{i}")
      c = create_connected_client(nick)
      c.join(@test_channel)
      clients << c
    end

    names_event = nil
    client.on(:names) { |event| names_event = event }

    client.names(@test_channel)
    wait_until { names_event }

    refute_nil names_event
    channel = client.channels[@test_channel]
    assert channel.users.size >= 5, "Should have at least 5 users"
  ensure
    client&.quit
    clients&.each do |c|
      c&.quit
    end
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

  def wait_for_mode(client, channel)
    mode_received = false
    client.on(:raw) do |event|
      msg = event.message
      mode_received = true if msg&.command == "MODE" && msg.params.include?(channel)
    end
    wait_until(timeout: 5) { mode_received }
  end

  def become_oper(client)
    oper_success = false
    client.on(:raw) { |event| oper_success = true if event.message&.command == "381" }
    client.raw("OPER testoper testpass")
    wait_until(timeout: 5) { oper_success }
  end
end
