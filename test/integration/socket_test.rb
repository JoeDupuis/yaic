# frozen_string_literal: true

require "test_helper"
require "timeout"

class SocketIntegrationTest < Minitest::Test
  def setup
    skip_unless_server_available
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_connect_to_server
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect
    assert_equal :connecting, socket.state
  ensure
    socket&.disconnect
  end

  def test_read_complete_message
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect

    message = read_with_timeout(socket, 5)
    refute_nil message, "Server should send initial message on connect"
    assert message.end_with?("\r\n", "\n")
  ensure
    socket&.disconnect
  end

  def test_write_message
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER #{@test_nick} 0 * :Test")

    responses = read_multiple(socket, 5)
    refute_empty responses, "Server should respond to registration"
  ensure
    socket&.disconnect
  end

  def test_disconnect
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect
    assert_equal :connecting, socket.state

    socket.disconnect
    assert_equal :disconnected, socket.state
  end

  def test_connect_with_ssl
    skip "SSL test infrastructure not yet implemented (see 16-ssl-test-infrastructure.md)"
  end

  def test_ssl_read_write
    skip "SSL test infrastructure not yet implemented (see 16-ssl-test-infrastructure.md)"
  end

  def test_connection_refused
    socket = Yaic::Socket.new("localhost", 59999, ssl: false)
    assert_raises(Errno::ECONNREFUSED) do
      socket.connect
    end
  end

  def test_connection_timeout
    socket = Yaic::Socket.new("10.255.255.1", 6667, ssl: false, connect_timeout: 1)
    assert_raises(Errno::ETIMEDOUT, Errno::EHOSTUNREACH, Errno::ECONNREFUSED) do
      socket.connect
    end
  end

  def test_read_on_closed_socket
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect
    socket.disconnect

    result = socket.read
    assert_nil result
  end

  private

  def skip_unless_server_available
    TCPSocket.new("localhost", 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end

  def read_with_timeout(socket, seconds)
    Timeout.timeout(seconds) do
      loop do
        msg = socket.read
        return msg if msg
        sleep 0.01
      end
    end
  rescue Timeout::Error
    nil
  end

  def read_multiple(socket, seconds)
    messages = []
    Timeout.timeout(seconds) do
      loop do
        msg = socket.read
        messages << msg if msg
        sleep 0.01
      end
    end
  rescue Timeout::Error
    messages
  end
end
