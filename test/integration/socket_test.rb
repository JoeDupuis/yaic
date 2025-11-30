# frozen_string_literal: true

require "test_helper"

class SocketIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @test_nick = unique_nick
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

    socket.write("NICK #{@test_nick}")
    socket.write("USER #{@test_nick} 0 * :Test")

    message = read_with_timeout(socket, 5)
    refute_nil message, "Server should send message after registration"
    assert message.end_with?("\r\n", "\n")
  ensure
    socket&.disconnect
  end

  def test_write_message
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER #{@test_nick} 0 * :Test")

    responses = []
    wait_until(timeout: 5) do
      msg = socket.read
      responses << msg if msg
      responses.any?
    end
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
    require_ssl_server_available
    socket = Yaic::Socket.new("localhost", 6697, ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
    socket.connect
    assert_equal :connecting, socket.state
  ensure
    socket&.disconnect
  end

  def test_ssl_read_write
    require_ssl_server_available
    socket = Yaic::Socket.new("localhost", 6697, ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
    socket.connect

    socket.write("NICK #{@test_nick}")
    socket.write("USER #{@test_nick} 0 * :Test")

    responses = []
    wait_until(timeout: 5) do
      msg = socket.read
      responses << msg if msg
      responses.any?
    end
    refute_empty responses, "Server should respond to registration over SSL"
  ensure
    socket&.disconnect
  end

  def test_ssl_verify_peer_fails_self_signed
    require_ssl_server_available
    socket = Yaic::Socket.new("localhost", 6697, ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER)
    assert_raises(OpenSSL::SSL::SSLError) do
      socket.connect
    end
  ensure
    socket&.disconnect
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

  def test_dns_resolution_failure
    socket = Yaic::Socket.new("this.host.does.not.exist.invalid", 6667, ssl: false)
    assert_raises(SocketError) do
      socket.connect
    end
  end

  def test_keepalive_option_set
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect
    tcp_socket = socket.instance_variable_get(:@socket)
    keepalive = tcp_socket.getsockopt(::Socket::SOL_SOCKET, ::Socket::SO_KEEPALIVE)
    assert keepalive.bool, "SO_KEEPALIVE should be enabled"
  ensure
    socket&.disconnect
  end

  def test_read_on_closed_socket
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.connect
    socket.disconnect

    result = socket.read
    assert_nil result
  end

  private

  def require_server_available
    TCPSocket.new("localhost", 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end

  def require_ssl_server_available
    require_server_available
    TCPSocket.new("localhost", 6697).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "SSL IRC server not available on port 6697. Restart with: bin/stop-irc-server && bin/start-irc-server"
  end

  def read_with_timeout(socket, seconds)
    result = nil
    wait_until(timeout: seconds) do
      result = socket.read
    end
    result
  end
end
