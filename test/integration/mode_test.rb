# frozen_string_literal: true

require "test_helper"

class ModeIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_get_own_user_modes
    client = create_connected_client(@test_nick)

    umode_received = false
    client.on(:raw) { |event| umode_received = true if event.message&.command == "221" }

    client.mode(@test_nick)
    sleep 0.5

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
    sleep 0.5

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
    sleep 0.5

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
    sleep 0.5

    assert mode_received, "Should receive 324 RPL_CHANNELMODEIS"
  ensure
    client&.quit
  end

  def test_set_channel_mode_as_op
    client = create_connected_client(@test_nick)

    become_oper(client)
    client.join(@test_channel)

    client.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    mode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      mode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+m")
    end

    client.mode(@test_channel, "+m")
    sleep 0.5

    assert mode_confirmed, "Should receive MODE confirmation for +m"
  ensure
    client&.quit
  end

  def test_give_op_to_user
    client1 = create_connected_client(@test_nick)

    become_oper(client1)
    client1.join(@test_channel)

    client1.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    mode_event = nil
    client2.on(:mode) { |event| mode_event = event }

    client1.mode(@test_channel, "+o", @test_nick2)
    sleep 0.5

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

    client.raw("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    mode_confirmed = false
    client.on(:raw) do |event|
      msg = event.message
      mode_confirmed = true if msg&.command == "MODE" && msg.params.include?("+k")
    end

    client.mode(@test_channel, "+k", "secret")
    sleep 0.5

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
    sleep 0.5

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
    deadline = Time.now + 5
    until oper_success || Time.now > deadline
      sleep 0.05
    end
  end
end
