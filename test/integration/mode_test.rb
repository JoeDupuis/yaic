# frozen_string_literal: true

require "test_helper"

class ModeIntegrationTest < Minitest::Test
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

  def test_get_own_user_modes
    client = create_connected_client(@test_nick)

    umode_received = false
    client.on(:raw) { |event| umode_received = true if event.message&.command == "221" }

    client.mode(@test_nick)
    wait_until { umode_received }

    assert umode_received, "Should receive 221 RPL_UMODEIS"
  ensure
    client&.quit
  end

  def test_set_invisible_mode
    client = create_connected_client(@test_nick)

    mode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      mode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+i")
    end

    client.mode(@test_nick, "+i")
    wait_until { mode_confirmed }

    assert mode_confirmed, "Should receive MODE confirmation for +i"
  ensure
    client&.quit
  end

  def test_cannot_set_other_user_modes
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    error_received = false
    client1.on(:raw) { |event| error_received = true if event.message&.command == "502" }

    client1.mode(@test_nick2, "+i")
    wait_until { error_received }

    assert error_received, "Should receive 502 ERR_USERSDONTMATCH"
  ensure
    client1&.quit
    client2&.quit
  end

  def test_get_channel_modes
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    mode_received = false
    client.on(:raw) { |event| mode_received = true if event.message&.command == "324" }

    client.mode(@test_channel)
    wait_until { mode_received }

    assert mode_received, "Should receive 324 RPL_CHANNELMODEIS"
  ensure
    client&.quit
  end

  def test_set_channel_mode_as_op
    client = create_connected_client(@test_nick)

    become_oper(client)
    client.join(@test_channel)

    samode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      samode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+o")
    end

    client.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_until { samode_confirmed }

    mode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      mode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+m")
    end

    client.mode(@test_channel, "+m")
    wait_until { mode_confirmed }

    assert mode_confirmed, "Should receive MODE confirmation for +m"
  ensure
    client&.quit
  end

  def test_give_op_to_user
    client1 = create_connected_client(@test_nick)

    become_oper(client1)
    client1.join(@test_channel)

    samode_confirmed = false
    client1.on(:raw) do |event|
      msg = event.message
      samode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+o")
    end

    client1.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_until { samode_confirmed }

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    mode_event = nil
    client2.on(:mode) { |event| mode_event = event }

    client1.mode(@test_channel, "+o", @test_nick2)
    wait_until { mode_event }

    refute_nil mode_event
    assert_equal "+o", mode_event.modes
    assert_equal [@test_nick2], mode_event.args
  ensure
    client1&.quit
    client2&.quit
  end

  def test_set_channel_key
    client = create_connected_client(@test_nick)

    become_oper(client)
    client.join(@test_channel)

    samode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      samode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+o")
    end

    client.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_until { samode_confirmed }

    mode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      mode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+k")
    end

    client.mode(@test_channel, "+k", "secret")
    wait_until { mode_confirmed }

    assert mode_confirmed, "Should receive MODE confirmation for +k"
    assert_equal "secret", client.channels[@test_channel].modes[:key]
  ensure
    client&.quit
  end

  def test_mode_without_permission
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    error_received = false
    client.on(:raw) { |event| error_received = true if event.message&.command == "482" }

    client.mode(@test_channel, "+m")
    wait_until { error_received }

    assert error_received, "Should receive 482 ERR_CHANOPRIVSNEEDED"
  ensure
    client&.quit
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

  def become_oper(client)
    oper_success = false
    client.on(:raw) { |event| oper_success = true if event.message&.command == "381" }
    client.raw("OPER testoper testpass")
    wait_until(timeout: 5) { oper_success }
  end
end
