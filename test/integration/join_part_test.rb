# frozen_string_literal: true

require "test_helper"
require "timeout"

class JoinPartIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_join_single_channel
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)

    join_confirmed = false
    names_received = false
    end_of_names = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          join_confirmed = true if msg&.command == "JOIN"
          names_received = true if msg&.command == "353"
          end_of_names = true if msg&.command == "366"
          break if join_confirmed && end_of_names
        end
        sleep 0.01
      end
    end

    assert join_confirmed, "Should receive JOIN confirmation"
    assert names_received, "Should receive RPL_NAMREPLY (353)"
    assert end_of_names, "Should receive RPL_ENDOFNAMES (366)"
    assert client.channels.key?(@test_channel)
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_join_channel_with_topic
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    socket1.write("JOIN #{@test_channel}")
    wait_for_join(client1, socket1, @test_channel)
    socket1.write("TOPIC #{@test_channel} :Test Topic")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        break if raw&.include?("TOPIC") || raw&.include?("332")
        sleep 0.01
      end
    end

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    client2.join(@test_channel)

    topic_received = false
    topic_text = nil

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          if msg&.command == "332"
            topic_received = true
            topic_text = msg.params[2]
          end
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end

    assert topic_received, "Should receive RPL_TOPIC (332)"
    assert_equal "Test Topic", topic_text
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_join_multiple_channels
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    chan_a = "#{@test_channel}a"
    chan_b = "#{@test_channel}b"
    chan_c = "#{@test_channel}c"

    client.join("#{chan_a},#{chan_b},#{chan_c}")

    joined_channels = []

    Timeout.timeout(10) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "JOIN"
            joined_channels << msg.params[0]
          end
          break if joined_channels.size >= 3
        end
        sleep 0.01
      end
    end

    assert_includes joined_channels, chan_a
    assert_includes joined_channels, chan_b
    assert_includes joined_channels, chan_c
  ensure
    socket&.write("PART #{chan_a},#{chan_b},#{chan_c}")
    client&.disconnect
  end

  def test_join_creates_channel_if_not_exists
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    unique_channel = "#new#{Process.pid}#{Time.now.to_i}"
    client.join(unique_channel)

    join_confirmed = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "JOIN" && msg&.params&.first == unique_channel
            join_confirmed = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert join_confirmed, "Channel should be created and joined"
    assert client.channels.key?(unique_channel)
  ensure
    socket&.write("PART #{unique_channel}")
    client&.disconnect
  end

  def test_part_single_channel
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    assert client.channels.key?(@test_channel)

    client.part(@test_channel)

    part_confirmed = false

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "PART" && msg&.params&.first == @test_channel
            part_confirmed = true
            break
          end
        end
        sleep 0.01
      end
    end

    assert part_confirmed, "Should receive PART confirmation"
    refute client.channels.key?(@test_channel)
  ensure
    client&.disconnect
  end

  def test_part_with_reason
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    client.part(@test_channel, "Going home")

    part_message = nil

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          if msg&.command == "PART" && msg&.params&.first == @test_channel
            part_message = msg
            break
          end
        end
        sleep 0.01
      end
    end

    refute_nil part_message
  ensure
    client&.disconnect
  end

  def test_part_channel_not_in_receives_error
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    error_event = nil
    client.on(:error) do |event|
      error_event = event if [403, 442].include?(event.numeric)
    end

    client.part("#notinchannel#{Process.pid}")

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if error_event
        end
        sleep 0.01
      end
    end

    refute_nil error_event
    assert_includes [403, 442], error_event.numeric
  ensure
    client&.disconnect
  end

  def test_join_event_on_self_join
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    join_event = nil
    client.on(:join) { |event| join_event = event }

    client.join(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if join_event
        end
        sleep 0.01
      end
    end

    refute_nil join_event
    assert_equal :join, join_event.type
    assert_equal @test_channel, join_event.channel
    assert_equal @test_nick, join_event.user.nick
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_join_event_on_other_join
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    other_join_event = nil
    client1.on(:join) do |event|
      other_join_event = event if event.user.nick == @test_nick2
    end

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)
    client2.join(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if other_join_event
        end
        sleep 0.01
      end
    end

    refute_nil other_join_event
    assert_equal :join, other_join_event.type
    assert_equal @test_channel, other_join_event.channel
    assert_equal @test_nick2, other_join_event.user.nick
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_part_event_on_self_part
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    client.join(@test_channel)
    wait_for_join(client, socket, @test_channel)

    part_event = nil
    client.on(:part) { |event| part_event = event }

    client.part(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          client.handle_message(msg) if msg
          break if part_event
        end
        sleep 0.01
      end
    end

    refute_nil part_event
    assert_equal :part, part_event.type
    assert_equal @test_channel, part_event.channel
    assert_equal @test_nick, part_event.user.nick
  ensure
    client&.disconnect
  end

  def test_part_event_on_other_part
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)
    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    other_part_event = nil
    client1.on(:part) do |event|
      other_part_event = event if event.user.nick == @test_nick2
    end

    client2.part(@test_channel)

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if other_part_event
        end
        sleep 0.01
      end
    end

    refute_nil other_part_event
    assert_equal :part, other_part_event.type
    assert_equal @test_channel, other_part_event.channel
    assert_equal @test_nick2, other_part_event.user.nick
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

  def wait_for_response(socket, *commands, seconds: 5)
    Timeout.timeout(seconds) do
      loop do
        raw = socket.read
        if raw
          msg = Yaic::Message.parse(raw)
          break if commands.include?(msg&.command)
        end
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
