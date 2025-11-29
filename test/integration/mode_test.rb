# frozen_string_literal: true

require "test_helper"
require "timeout"

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
    socket = client.instance_variable_get(:@socket)

    drain_messages(socket)

    client.mode(@test_nick)

    umode_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "221"
            umode_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert umode_received, "Should receive 221 RPL_UMODEIS"
  ensure
    client&.disconnect
  end

  def test_set_invisible_mode
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    drain_messages(socket)

    client.mode(@test_nick, "+i")

    mode_confirmed = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "MODE" && msg.params.include?("+i")
            mode_confirmed = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert mode_confirmed, "Should receive MODE confirmation for +i"
  ensure
    client&.disconnect
  end

  def test_cannot_set_other_user_modes
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    client2.instance_variable_get(:@socket)

    drain_messages(socket1)

    client1.mode(@test_nick2, "+i")

    error_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          if msg&.command == "502"
            error_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert error_received, "Should receive 502 ERR_USERSDONTMATCH"
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_get_channel_modes
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    drain_messages(socket)

    client.mode(@test_channel)

    mode_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "324"
            mode_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert mode_received, "Should receive 324 RPL_CHANNELMODEIS"
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_set_channel_mode_as_op
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    become_oper(socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    socket.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket, @test_channel)

    drain_messages(socket)

    client.mode(@test_channel, "+m")

    mode_confirmed = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "MODE" && msg.params.include?("+m")
            mode_confirmed = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert mode_confirmed, "Should receive MODE confirmation for +m"
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_give_op_to_user
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
    drain_messages(socket2)

    client1.mode(@test_channel, "+o", @test_nick2)

    mode_event = nil
    client2.on(:mode) { |event| mode_event = event }

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if mode_event
        end
        sleep 0.01
      end
    end

    refute_nil mode_event
    assert_equal "+o", mode_event.modes
    assert_equal [@test_nick2], mode_event.args
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_set_channel_key
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    become_oper(socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    socket.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket, @test_channel)

    drain_messages(socket)

    client.mode(@test_channel, "+k", "secret")

    mode_confirmed = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "MODE" && msg.params.include?("+k")
            mode_confirmed = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert mode_confirmed, "Should receive MODE confirmation for +k"
    assert_equal "secret", client.channels[@test_channel].modes[:key]
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_mode_without_permission
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    drain_messages(socket)

    client.mode(@test_channel, "+m")

    error_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
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
    socket&.write("PART #{@test_channel}")
    client&.disconnect
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
