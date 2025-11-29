# frozen_string_literal: true

require "test_helper"
require "timeout"

class PrivmsgNoticeIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_send_privmsg_to_channel
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    socket.write("JOIN #{@test_channel}")
    wait_for_join(client, socket, @test_channel)

    client.privmsg(@test_channel, "Hello")

    raw = nil
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw.nil?
        sleep 0.01
      end
    end
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_send_privmsg_to_user
    client1 = create_connected_client(@test_nick)
    client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    received_event = nil
    client2.on(:message) { |event| received_event = event }

    client1.privmsg(@test_nick2, "Hello")

    Timeout.timeout(5) do
      loop do
        raw = socket2.read
        if raw
          msg = Yaic::Message.parse(raw)
          client2.handle_message(msg) if msg
          break if received_event
        end
        sleep 0.01
      end
    end

    refute_nil received_event
    assert_equal @test_nick, received_event.source.nick
    assert_equal @test_nick2, received_event.target
    assert_equal "Hello", received_event.text
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_send_notice_to_channel
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    socket.write("JOIN #{@test_channel}")
    wait_for_join(client, socket, @test_channel)

    client.notice(@test_channel, "Announcement")

    raw = nil
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw.nil?
        sleep 0.01
      end
    end
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_send_message_with_special_characters
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    socket.write("JOIN #{@test_channel}")
    wait_for_join(client, socket, @test_channel)

    client.privmsg(@test_channel, "Hello :) world")

    raw = nil
    Timeout.timeout(5) do
      loop do
        raw = socket.read
        break if raw.nil?
        sleep 0.01
      end
    end
  ensure
    socket&.write("PART #{@test_channel}")
    client&.disconnect
  end

  def test_receive_privmsg_from_user
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    message_event = nil
    client1.on(:message) { |event| message_event = event }

    socket2.write("PRIVMSG #{@test_nick} :hello from test")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if message_event
        end
        sleep 0.01
      end
    end

    refute_nil message_event
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_nick, message_event.target
    assert_equal "hello from test", message_event.text
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_receive_privmsg_in_channel
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    socket1.write("JOIN #{@test_channel}")
    wait_for_join(client1, socket1, @test_channel)

    socket2.write("JOIN #{@test_channel}")
    wait_for_join(client2, socket2, @test_channel)

    message_event = nil
    client1.on(:message) { |event| message_event = event }

    socket2.write("PRIVMSG #{@test_channel} :hello channel")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if message_event
        end
        sleep 0.01
      end
    end

    refute_nil message_event
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_channel, message_event.target
    assert_equal "hello channel", message_event.text
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_receive_notice
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    notice_event = nil
    client1.on(:notice) { |event| notice_event = event }

    socket2.write("NOTICE #{@test_nick} :FYI info here")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if notice_event
        end
        sleep 0.01
      end
    end

    refute_nil notice_event
    assert_equal :notice, notice_event.type
    assert_equal @test_nick2, notice_event.source.nick
    assert_equal @test_nick, notice_event.target
    assert_equal "FYI info here", notice_event.text
  ensure
    client1&.disconnect
    client2&.disconnect
  end

  def test_distinguish_channel_from_private_message
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)

    socket1.write("JOIN #{@test_channel}")
    wait_for_join(client1, socket1, @test_channel)

    socket2.write("JOIN #{@test_channel}")
    wait_for_join(client2, socket2, @test_channel)

    targets = []
    client1.on(:message) { |event| targets << event.target }

    socket2.write("PRIVMSG #{@test_channel} :channel msg")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if targets.size >= 1
        end
        sleep 0.01
      end
    end

    socket2.write("PRIVMSG #{@test_nick} :private msg")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if targets.size >= 2
        end
        sleep 0.01
      end
    end

    assert_includes targets, @test_channel
    assert_includes targets, @test_nick
  ensure
    socket1&.write("PART #{@test_channel}")
    socket2&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_send_to_nonexistent_nick_receives_error
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    error_event = nil
    client.on(:error) do |event|
      error_event = event if event.numeric == 401
    end

    client.privmsg("nonexistent_user_xyz_12345", "Hello")

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
    assert_equal :error, error_event.type
    assert_equal 401, error_event.numeric
  ensure
    client&.disconnect
  end

  def test_send_to_channel_not_joined
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    error_event = nil
    client.on(:error) do |event|
      error_event = event if event.numeric == 403 || event.numeric == 404
    end

    client.privmsg("#nonexistent_chan_xyz", "Hello")

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
    assert_equal :error, error_event.type
    assert_includes [403, 404], error_event.numeric
  ensure
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
            break
          end
        end
        sleep 0.01
      end
    end
    joined
  end
end
