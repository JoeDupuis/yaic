# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def test_initial_state_is_disconnected
    client = Yaic::Client.new(host: "localhost", port: 6667)
    assert_equal :disconnected, client.state
  end

  def test_state_transitions_to_connecting_on_connect
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.instance_variable_set(:@socket, mock_socket)

    client.connect
    assert_equal :connecting, client.state
  end

  def test_state_transitions_to_registering_after_socket_connected
    mock_socket = MockSocket.new
    mock_socket.connect_response = [:connected]

    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick",
      user: "testuser",
      realname: "Test User"
    )
    client.instance_variable_set(:@socket, mock_socket)

    client.connect
    client.on_socket_connected

    assert_equal :registering, client.state
    assert mock_socket.written.any? { |m| m.include?("NICK testnick") }
    assert mock_socket.written.any? { |m| m.include?("USER testuser 0 * :Test User") }
  end

  def test_state_transitions_to_connected_on_rpl_welcome
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick",
      user: "testuser",
      realname: "Test User"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :registering)

    message = Yaic::Message.parse(":server.example.com 001 testnick :Welcome to the IRC Network\r\n")
    client.handle_message(message)

    assert_equal :connected, client.state
  end

  def test_state_remains_registering_on_nick_collision
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick",
      user: "testuser",
      realname: "Test User"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :registering)

    message = Yaic::Message.parse(":server.example.com 433 * testnick :Nickname is already in use\r\n")
    client.handle_message(message)

    assert_equal :registering, client.state
    assert mock_socket.written.any? { |m| m.include?("NICK testnick_") }
  end

  def test_registration_with_password_sends_pass_first
    mock_socket = MockSocket.new

    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick",
      user: "testuser",
      realname: "Test User",
      password: "secret"
    )
    client.instance_variable_set(:@socket, mock_socket)

    client.connect
    client.on_socket_connected

    pass_idx = mock_socket.written.find_index { |m| m.include?("PASS secret") }
    nick_idx = mock_socket.written.find_index { |m| m.include?("NICK testnick") }
    user_idx = mock_socket.written.find_index { |m| m.include?("USER testuser") }

    refute_nil pass_idx, "PASS should be sent"
    refute_nil nick_idx, "NICK should be sent"
    refute_nil user_idx, "USER should be sent"
    assert pass_idx < nick_idx, "PASS should be sent before NICK"
    assert nick_idx < user_idx, "NICK should be sent before USER"
  end

  def test_responds_to_ping_with_pong
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    message = Yaic::Message.parse("PING :irc.example.com\r\n")
    client.handle_message(message)

    assert mock_socket.written.any? { |m| m.include?("PONG irc.example.com") }
  end

  def test_responds_to_ping_without_colon
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    message = Yaic::Message.parse("PING token123\r\n")
    client.handle_message(message)

    assert mock_socket.written.any? { |m| m.include?("PONG token123") }
  end

  def test_responds_to_ping_during_registration
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :registering)

    message = Yaic::Message.parse("PING :test.server\r\n")
    client.handle_message(message)

    assert mock_socket.written.any? { |m| m.include?("PONG test.server") }
  end

  def test_pong_response_with_spaces_uses_trailing
    mock_socket = MockSocket.new
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    message = Yaic::Message.parse("PING :some server\r\n")
    client.handle_message(message)

    pong = mock_socket.written.find { |m| m.include?("PONG") }
    assert_equal "PONG :some server\r\n", pong
  end

  def test_last_received_at_updated_on_message
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@state, :connected)

    before = Time.now
    message = Yaic::Message.parse(":server 001 testnick :Welcome\r\n")
    client.handle_message(message)

    assert client.last_received_at >= before
  end

  def test_connection_stale_when_no_data_received
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@state, :connected)
    client.instance_variable_set(:@last_received_at, Time.now - 200)

    assert client.connection_stale?
  end

  def test_connection_not_stale_with_recent_data
    client = Yaic::Client.new(
      host: "localhost",
      port: 6667,
      nick: "testnick"
    )
    client.instance_variable_set(:@state, :connected)
    client.instance_variable_set(:@last_received_at, Time.now - 10)

    refute client.connection_stale?
  end

  class MockSocket
    attr_accessor :connect_response
    attr_reader :written

    def initialize
      @written = []
      @connect_response = []
      @state = :disconnected
    end

    def connect
      @state = :connecting
    end

    def disconnect
      @state = :disconnected
    end

    def write(message)
      @written << message.to_s
    end

    def read
      nil
    end

    attr_reader :state
  end
end
