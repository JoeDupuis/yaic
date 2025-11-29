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

  def test_register_single_handler
    client = Yaic::Client.new(host: "localhost", port: 6667)
    called = false
    client.on(:message) { called = true }

    handlers = client.instance_variable_get(:@handlers)
    assert_equal 1, handlers[:message].size
  end

  def test_register_multiple_handlers_for_same_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.on(:message) {}
    client.on(:message) {}
    client.on(:message) {}

    handlers = client.instance_variable_get(:@handlers)
    assert_equal 3, handlers[:message].size
  end

  def test_register_handlers_for_different_events
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.on(:message) {}
    client.on(:join) {}
    client.on(:part) {}

    handlers = client.instance_variable_get(:@handlers)
    assert_equal 1, handlers[:message].size
    assert_equal 1, handlers[:join].size
    assert_equal 1, handlers[:part].size
  end

  def test_on_returns_self_for_chaining
    client = Yaic::Client.new(host: "localhost", port: 6667)
    result = client.on(:message) {}
    assert_equal client, result
  end

  def test_off_removes_handlers
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.on(:message) {}
    client.on(:message) {}
    client.off(:message)

    handlers = client.instance_variable_get(:@handlers)
    assert_nil handlers[:message]
  end

  def test_off_returns_self_for_chaining
    client = Yaic::Client.new(host: "localhost", port: 6667)
    result = client.off(:message)
    assert_equal client, result
  end

  def test_dispatch_calls_all_handlers_in_order
    client = Yaic::Client.new(host: "localhost", port: 6667)
    called = []
    client.on(:message) { called << 1 }
    client.on(:message) { called << 2 }
    client.on(:message) { called << 3 }

    message = Yaic::Message.parse(":nick!user@host PRIVMSG #test :hello\r\n")
    client.handle_message(message)

    assert_equal [1, 2, 3], called
  end

  def test_dispatch_with_correct_payload
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:message) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!user@host PRIVMSG #chan :hello\r\n")
    client.handle_message(message)

    assert_equal :message, received_event.type
    assert_equal "nick", received_event.source.nick
    assert_equal "#chan", received_event.target
    assert_equal "hello", received_event.text
  end

  def test_handler_exception_does_not_stop_others
    client = Yaic::Client.new(host: "localhost", port: 6667)
    called = []
    client.on(:message) { called << 1 }
    client.on(:message) { raise "oops" }
    client.on(:message) { called << 3 }

    message = Yaic::Message.parse(":nick!user@host PRIVMSG #test :hello\r\n")
    client.handle_message(message)

    assert_equal [1, 3], called
  end

  def test_unknown_event_type_silently_ignored
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.send(:emit, :foo, nil)
  end

  def test_privmsg_triggers_message_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_type = nil
    client.on(:message) { |event| received_type = event.type }

    message = Yaic::Message.parse(":nick!user@host PRIVMSG #test :hello\r\n")
    client.handle_message(message)

    assert_equal :message, received_type
  end

  def test_notice_triggers_notice_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_type = nil
    client.on(:notice) { |event| received_type = event.type }

    message = Yaic::Message.parse(":nick!user@host NOTICE #test :hello\r\n")
    client.handle_message(message)

    assert_equal :notice, received_type
  end

  def test_join_triggers_join_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_type = nil
    client.on(:join) { |event| received_type = event.type }

    message = Yaic::Message.parse(":nick!user@host JOIN #test\r\n")
    client.handle_message(message)

    assert_equal :join, received_type
  end

  def test_001_triggers_connect_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_type = nil
    client.on(:connect) { |event| received_type = event.type }

    message = Yaic::Message.parse(":server.example.com 001 testnick :Welcome\r\n")
    client.handle_message(message)

    assert_equal :connect, received_type
  end

  def test_error_numeric_triggers_error_event
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    received_event = nil
    client.on(:error) { |event| received_event = event }

    message = Yaic::Message.parse(":server.example.com 433 * testnick :Nickname in use\r\n")
    client.handle_message(message)

    assert_equal :error, received_event.type
    assert_equal 433, received_event.numeric
  end

  def test_raw_event_emitted_for_every_message
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667)
    client.instance_variable_set(:@socket, mock_socket)
    raw_events = []
    client.on(:raw) { |event| raw_events << event }

    message = Yaic::Message.parse("PING :server\r\n")
    client.handle_message(message)

    assert_equal 1, raw_events.size
    assert_equal :raw, raw_events[0].type
    assert_equal message, raw_events[0].message
  end

  def test_both_raw_and_typed_events_emitted
    client = Yaic::Client.new(host: "localhost", port: 6667)
    events = []
    client.on(:raw) { |event| events << event.type }
    client.on(:message) { |event| events << event.type }

    message = Yaic::Message.parse(":nick!user@host PRIVMSG #test :hello\r\n")
    client.handle_message(message)

    assert_includes events, :raw
    assert_includes events, :message
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
