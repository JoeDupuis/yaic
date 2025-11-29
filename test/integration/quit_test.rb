# frozen_string_literal: true

require "test_helper"
require "timeout"

class QuitIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_quit_without_reason
    client = create_connected_client(@test_nick)
    client.instance_variable_get(:@socket)

    client.quit

    assert_equal :disconnected, client.state
  ensure
    client&.disconnect
  end

  def test_quit_with_reason
    client = create_connected_client(@test_nick)
    client.instance_variable_get(:@socket)

    client.quit("Bye!")

    assert_equal :disconnected, client.state
  ensure
    client&.disconnect
  end

  def test_receive_other_user_quit
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    client1.join(@test_channel)
    wait_for_join(client1, socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    socket2 = client2.instance_variable_get(:@socket)
    client2.join(@test_channel)
    wait_for_join(client2, socket2, @test_channel)

    drain_messages(socket1)

    quit_event = nil
    client1.on(:quit) do |event|
      quit_event = event if event.user.nick == @test_nick2
    end

    client2.quit("Leaving now")

    Timeout.timeout(5) do
      loop do
        raw = socket1.read
        if raw
          msg = Yaic::Message.parse(raw)
          client1.handle_message(msg) if msg
          break if quit_event
        end
        sleep 0.01
      end
    end

    refute_nil quit_event
    assert_equal :quit, quit_event.type
    assert_equal @test_nick2, quit_event.user.nick
  ensure
    socket1&.write("PART #{@test_channel}")
    client1&.disconnect
    client2&.disconnect
  end

  def test_detect_netsplit_quit
    client = create_connected_client(@test_nick)
    client.instance_variable_get(:@socket)

    quit_event = nil
    client.on(:quit) { |event| quit_event = event }

    message = Yaic::Message.parse(":othernick!user@host QUIT :*.net *.split\r\n")
    client.handle_message(message)

    refute_nil quit_event
    assert_equal :quit, quit_event.type
    assert_equal "*.net *.split", quit_event.reason
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
          end
          break if msg&.command == "366"
        end
        sleep 0.01
      end
    end
    joined
  end

  def drain_messages(socket)
    loop do
      raw = socket.read
      break if raw.nil?
    end
  end
end
