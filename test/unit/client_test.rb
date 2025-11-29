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

  def test_privmsg_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.privmsg("#test", "Hello")

    assert_equal "PRIVMSG #test :Hello\r\n", mock_socket.written.last
  end

  def test_privmsg_with_colon_in_text
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.privmsg("#test", ":smile:")

    assert_equal "PRIVMSG #test ::smile:\r\n", mock_socket.written.last
  end

  def test_notice_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.notice("nick", "Info")

    assert_equal "NOTICE nick :Info\r\n", mock_socket.written.last
  end

  def test_privmsg_parses_event_correctly
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:message) { |event| received_event = event }

    message = Yaic::Message.parse(":dan!d@host PRIVMSG #ruby :Hello everyone\r\n")
    client.handle_message(message)

    assert_equal :message, received_event.type
    assert_equal "dan", received_event.source.nick
    assert_equal "#ruby", received_event.target
    assert_equal "Hello everyone", received_event.text
  end

  def test_notice_parses_event_correctly
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:notice) { |event| received_event = event }

    message = Yaic::Message.parse(":server NOTICE * :Looking up hostname\r\n")
    client.handle_message(message)

    assert_equal :notice, received_event.type
    assert_equal "server", received_event.source.raw
    assert_equal "*", received_event.target
    assert_equal "Looking up hostname", received_event.text
  end

  def test_msg_is_alias_for_privmsg
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.msg("#test", "Hello via alias")

    assert_equal "PRIVMSG #test :Hello via alias\r\n", mock_socket.written.last
  end

  def test_join_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.join("#test")

    assert_equal "JOIN #test\r\n", mock_socket.written.last
  end

  def test_join_with_key_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.join("#test", "secret")

    assert_equal "JOIN #test :secret\r\n", mock_socket.written.last
  end

  def test_part_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.part("#test")

    assert_equal "PART #test\r\n", mock_socket.written.last
  end

  def test_part_with_reason_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.part("#test", "Bye all")

    assert_equal "PART #test :Bye all\r\n", mock_socket.written.last
  end

  def test_parse_join_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:join) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!u@h JOIN #test\r\n")
    client.handle_message(message)

    assert_equal :join, received_event.type
    assert_equal "#test", received_event.channel
    assert_equal "nick", received_event.user.nick
  end

  def test_parse_part_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:part) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!u@h PART #test :Later\r\n")
    client.handle_message(message)

    assert_equal :part, received_event.type
    assert_equal "#test", received_event.channel
    assert_equal "nick", received_event.user.nick
    assert_equal "Later", received_event.reason
  end

  def test_channels_attribute_exists
    client = Yaic::Client.new(host: "localhost", port: 6667)
    assert_equal({}, client.channels)
  end

  def test_join_adds_channel_to_tracking
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(message)

    assert client.channels.key?("#test")
    assert_instance_of Yaic::Channel, client.channels["#test"]
    assert_equal "#test", client.channels["#test"].name
  end

  def test_part_removes_channel_from_tracking
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(join_message)
    assert client.channels.key?("#test")

    part_message = Yaic::Message.parse(":testnick!user@host PART #test :Leaving\r\n")
    client.handle_message(part_message)
    refute client.channels.key?("#test")
  end

  def test_other_user_join_does_not_add_channel
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")

    message = Yaic::Message.parse(":othernick!user@host JOIN #test\r\n")
    client.handle_message(message)

    refute client.channels.key?("#test")
  end

  def test_other_user_part_does_not_remove_channel
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(join_message)
    assert client.channels.key?("#test")

    part_message = Yaic::Message.parse(":othernick!user@host PART #test :Bye\r\n")
    client.handle_message(part_message)
    assert client.channels.key?("#test")
  end

  def test_quit_formats_correctly_without_reason
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.quit

    assert_equal "QUIT\r\n", mock_socket.written.last
  end

  def test_quit_formats_correctly_with_reason
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.quit("Going away")

    assert_equal "QUIT :Going away\r\n", mock_socket.written.last
  end

  def test_parse_quit_event
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:quit) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!u@h QUIT :Quit: Leaving\r\n")
    client.handle_message(message)

    assert_equal :quit, received_event.type
    assert_equal "nick", received_event.user.nick
    assert_equal "Quit: Leaving", received_event.reason
  end

  def test_parse_netsplit_quit
    client = Yaic::Client.new(host: "localhost", port: 6667)
    received_event = nil
    client.on(:quit) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!u@h QUIT :hub.net leaf.net\r\n")
    client.handle_message(message)

    assert_equal :quit, received_event.type
    assert_equal "hub.net leaf.net", received_event.reason
  end

  def test_state_after_quit
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.quit

    assert_equal :disconnected, client.state
  end

  def test_channels_cleared_after_quit
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message1 = Yaic::Message.parse(":testnick!user@host JOIN #test1\r\n")
    client.handle_message(join_message1)
    join_message2 = Yaic::Message.parse(":testnick!user@host JOIN #test2\r\n")
    client.handle_message(join_message2)

    assert_equal 2, client.channels.size

    client.quit

    assert_equal 0, client.channels.size
  end

  def test_disconnect_emits_event_after_quit
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    disconnect_event = nil
    client.on(:disconnect) { |event| disconnect_event = event }

    client.quit

    refute_nil disconnect_event
    assert_equal :disconnect, disconnect_event.type
  end

  def test_nick_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.nick("newnick")

    assert_equal "NICK newnick\r\n", mock_socket.written.last
  end

  def test_parse_nick_event
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    received_event = nil
    client.on(:nick) { |event| received_event = event }

    message = Yaic::Message.parse(":old!u@h NICK new\r\n")
    client.handle_message(message)

    assert_equal :nick, received_event.type
    assert_equal "old", received_event.old_nick
    assert_equal "new", received_event.new_nick
  end

  def test_track_own_nick_change
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "oldnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    assert_equal "oldnick", client.nick

    message = Yaic::Message.parse(":oldnick!u@h NICK newnick\r\n")
    client.handle_message(message)

    assert_equal "newnick", client.nick
  end

  def test_update_user_in_channels_on_nick_change
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    channel = client.channels["#test"]
    channel.users["bob"] = {}

    nick_message = Yaic::Message.parse(":bob!u@h NICK robert\r\n")
    client.handle_message(nick_message)

    refute channel.users.key?("bob")
    assert channel.users.key?("robert")
  end

  def test_nick_change_updates_multiple_channels
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message1 = Yaic::Message.parse(":testnick!user@host JOIN #test1\r\n")
    client.handle_message(join_message1)
    join_message2 = Yaic::Message.parse(":testnick!user@host JOIN #test2\r\n")
    client.handle_message(join_message2)

    client.channels["#test1"].users["alice"] = {}
    client.channels["#test2"].users["alice"] = {}

    nick_message = Yaic::Message.parse(":alice!u@h NICK alicia\r\n")
    client.handle_message(nick_message)

    refute client.channels["#test1"].users.key?("alice")
    assert client.channels["#test1"].users.key?("alicia")
    refute client.channels["#test2"].users.key?("alice")
    assert client.channels["#test2"].users.key?("alicia")
  end

  def test_topic_get_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.topic("#test")

    assert_equal "TOPIC #test\r\n", mock_socket.written.last
  end

  def test_topic_set_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.topic("#test", "Hello")

    assert_equal "TOPIC #test :Hello\r\n", mock_socket.written.last
  end

  def test_topic_clear_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.topic("#test", "")

    assert_equal "TOPIC #test :\r\n", mock_socket.written.last
  end

  def test_parse_topic_event
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    received_event = nil
    client.on(:topic) { |event| received_event = event }

    message = Yaic::Message.parse(":nick!u@h TOPIC #test :New topic\r\n")
    client.handle_message(message)

    assert_equal :topic, received_event.type
    assert_equal "#test", received_event.channel
    assert_equal "New topic", received_event.topic
    assert_equal "nick", received_event.setter.nick
  end

  def test_parse_rpl_topic
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    received_event = nil
    client.on(:topic) { |event| received_event = event }

    message = Yaic::Message.parse(":server 332 mynick #test :The topic\r\n")
    client.handle_message(message)

    assert_equal :topic, received_event.type
    assert_equal "#test", received_event.channel
    assert_equal "The topic", received_event.topic
  end

  def test_parse_rpl_topicwhotime
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 333 mynick #test setter 1234567890\r\n")
    client.handle_message(message)

    channel = client.channels["#test"]
    assert_equal "setter", channel.topic_setter
    assert_equal Time.at(1234567890), channel.topic_time
  end

  def test_update_channel_topic_on_change
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    topic_message = Yaic::Message.parse(":nick!u@h TOPIC #test :Updated topic\r\n")
    client.handle_message(topic_message)

    channel = client.channels["#test"]
    assert_equal "Updated topic", channel.topic
    assert_equal "nick", channel.topic_setter
  end

  def test_topic_from_join_rpl_topic
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":testnick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    rpl_topic = Yaic::Message.parse(":server 332 testnick #test :Welcome topic\r\n")
    client.handle_message(rpl_topic)

    channel = client.channels["#test"]
    assert_equal "Welcome topic", channel.topic
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
