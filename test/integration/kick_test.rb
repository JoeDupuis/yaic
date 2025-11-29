# frozen_string_literal: true

require "test_helper"
require "timeout"

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

    become_oper(socket1)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    client1.kick(@test_channel, @test_nick2)

    kick_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          if msg&.command == "KICK"
            kick_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert kick_received, "Should receive KICK confirmation"
  ensure
    socket1&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_kick_with_reason
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    client1.kick(@test_channel, @test_nick2, "Breaking rules")

    kick_reason = nil

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          if msg&.command == "KICK"
            kick_reason = msg.params[2]
            break
          end
        end
        sleep 0.01
      end
    end

    assert_equal "Breaking rules", kick_reason
  ensure
    socket1&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_kick_without_permission
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket2)

    client2.kick(@test_channel, @test_nick)

    error_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          if msg&.command == "482"
            error_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert error_received, "Should receive 482 ERR_CHANOPRIVSNEEDED"
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_kick_non_existent_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    drain_messages(socket1)

    client1.kick(@test_channel, "nobodyhere")

    error_received = false
    error_code = nil

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          if msg&.command == "441" || msg&.command == "401"
            error_received = true
            error_code = msg.command
            break
          end
        end
        sleep 0.01
      end
    end

    assert error_received, "Should receive 441 ERR_USERNOTINCHANNEL or 401 ERR_NOSUCHNICK"
  ensure
    socket1&.write("PART #{@test_channel}")
    client1&.disconnect
  end

  def test_receive_kick_others
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    third_nick = "v#{Process.pid}#{Time.now.to_i % 10000}"
    client3 = create_connected_client(third_nick)
    socket3 = client3.instance_variable_get(:@socket)

    client3.join(@test_channel)
    wait_for_join(client3, socket3, @test_channel)

    drain_messages(socket2)

    kick_event = nil
    client2.on(:kick) { |event| kick_event = event }

    socket1.write("KICK #{@test_channel} #{third_nick} :Goodbye")

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if kick_event
        end
        sleep 0.01
      end
    end

    refute_nil kick_event
    assert_equal :kick, kick_event.type
    assert_equal @test_channel, kick_event.channel
    assert_equal third_nick, kick_event.user
    assert_equal @test_nick, kick_event.by.nick
    assert_equal "Goodbye", kick_event.reason
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
    client3&.disconnect
  end

  def test_receive_kick_self
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket2)

    kick_event = nil
    client2.on(:kick) { |event| kick_event = event }

    assert client2.channels.key?(@test_channel)

    socket1.write("KICK #{@test_channel} #{@test_nick2} :You are kicked")

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if kick_event
        end
        sleep 0.01
      end
    end

    refute_nil kick_event
    assert_equal :kick, kick_event.type
    assert_equal @test_channel, kick_event.channel
    assert_equal @test_nick2, kick_event.user
    refute client2.channels.key?(@test_channel), "Channel should be removed after being kicked"
  ensure
    socket1&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
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
    client.on_socket_connected

    socket = client.instance_variable_get(:@socket)
    wait_for_connection(client, socket)

    client
  end

  def wait_for_connection(client, socket, seconds = 10)
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if client.state == :connected
        end
        sleep 0.01
      end
    end
  end

  def wait_for_join(client, socket, channel, seconds = 5)
    joined = false
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "JOIN" && msg&.params&.first == channel
            joined = true
          end
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end
    joined
  end

  def wait_for_mode(socket, channel)
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw&.include?("MODE") && raw.include?(channel)
        sleep 0.01
      end
    end
  end

  def become_oper(socket)
    socket.write("OPER testoper testpass")
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw&.include?("381")
        sleep 0.01
      end
    end
  end

  def drain_messages(socket)
    loop do
      raw = socket.read
      break if raw.nil?
    end
  end
end
