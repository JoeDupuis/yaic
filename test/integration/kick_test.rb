# frozen_string_literal: true

require "test_helper"

class KickIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_kick_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(client1, socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    kick_received = false
    client1.on(:kick) { |_event| kick_received = true }

    client1.kick(@test_channel, @test_nick2)
    sleep 0.5

    assert kick_received, "Should receive KICK confirmation"
  ensure
    client1&.quit
    client2&.quit
  end

  def test_kick_with_reason
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(client1, socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    kick_reason = nil
    client1.on(:kick) { |event| kick_reason = event.reason }

    client1.kick(@test_channel, @test_nick2, "Breaking rules")
    sleep 0.5

    assert_equal "Breaking rules", kick_reason
  ensure
    client1&.quit
    client2&.quit
  end

  def test_kick_without_permission
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    error_received = false
    client2.on(:error) { |event| error_received = true if event.numeric == 482 }

    client2.kick(@test_channel, @test_nick)
    sleep 0.5

    assert error_received, "Should receive 482 ERR_CHANOPRIVSNEEDED"
  ensure
    client1&.quit
    client2&.quit
  end

  def test_kick_non_existent_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(client1, socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    error_received = false
    client1.on(:error) { |event| error_received = true if [441, 401].include?(event.numeric) }

    client1.kick(@test_channel, "nobodyhere")
    sleep 0.5

    assert error_received, "Should receive 441 ERR_USERNOTINCHANNEL or 401 ERR_NOSUCHNICK"
  ensure
    client1&.quit
  end

  def test_receive_kick_others
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(client1, socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    third_nick = "v#{Process.pid}#{Time.now.to_i % 10000}"
    client3 = create_connected_client(third_nick)
    client3.join(@test_channel)

    kick_event = nil
    client2.on(:kick) { |event| kick_event = event }

    socket1.write("KICK #{@test_channel} #{third_nick} :Goodbye")
    sleep 0.5

    refute_nil kick_event
    assert_equal :kick, kick_event.type
    assert_equal @test_channel, kick_event.channel
    assert_equal third_nick, kick_event.user
    assert_equal @test_nick, kick_event.by.nick
    assert_equal "Goodbye", kick_event.reason
  ensure
    client1&.quit
    client2&.quit
    client3&.quit
  end

  def test_receive_kick_self
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(client1, socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    sleep 0.5

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    kick_event = nil
    client2.on(:kick) { |event| kick_event = event }

    assert client2.channels.key?(@test_channel)

    socket1.write("KICK #{@test_channel} #{@test_nick2} :You are kicked")
    sleep 0.5

    refute_nil kick_event
    assert_equal :kick, kick_event.type
    assert_equal @test_channel, kick_event.channel
    assert_equal @test_nick2, kick_event.user
    refute client2.channels.key?(@test_channel), "Channel should be removed after being kicked"
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

  def become_oper(client, socket)
    oper_success = false
    client.on(:raw) { |event| oper_success = true if event.message&.command == "381" }
    socket.write("OPER testoper testpass")
    deadline = Time.now + 5
    until oper_success || Time.now > deadline
      sleep 0.05
    end
  end
end
