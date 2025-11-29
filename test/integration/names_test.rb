# frozen_string_literal: true

require "test_helper"
require "timeout"

class NamesIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_get_names
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    drain_messages(socket)

    client.names(@test_channel)

    names_received = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "366"
            names_received = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert names_received, "Should receive RPL_ENDOFNAMES"

    channel = client.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have self in user list"
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_names_with_prefixes
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

    client2.names(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end

    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick)
    assert_includes channel.users[@test_nick], :op
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_names_at_join
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

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end

    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have first user in list"
    assert channel.users.key?(@test_nick2), "Should have self in list"
    assert_includes channel.users[@test_nick], :op
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_multi_message_names
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    become_oper(socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    socket.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket, @test_channel)

    clients = []
    4.times do |i|
      nick = "x#{Process.pid}#{i}#{Time.now.to_i % 10000}"
      c = create_connected_client(nick)
      s = c.instance_variable_get(:@socket)
      c.join(@test_channel)
      wait_for_join(c, s, @test_channel)
      clients << c
    end

    drain_messages(socket)

    names_event = nil
    client.on(:names) { |event| names_event = event }

    client.names(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if names_event
        end
        sleep 0.01
      end
    end

    refute_nil names_event
    channel = client.channels[@test_channel]
    assert channel.users.size >= 5, "Should have at least 5 users"
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
    clients&.each do |c|
      c&.disconnect
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
