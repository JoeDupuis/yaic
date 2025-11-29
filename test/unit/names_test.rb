# frozen_string_literal: true

require "test_helper"

class NamesTest < Minitest::Test
  def test_names_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.names("#test")

    assert_equal "NAMES #test\r\n", mock_socket.written.last
  end

  def test_parse_rpl_namreply_basic
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :@op +voice regular\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("op")
    assert channel.users.key?("voice")
    assert channel.users.key?("regular")
  end

  def test_parse_prefix_op
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :@dan\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("dan")
    assert_includes channel.users["dan"], :op
  end

  def test_parse_prefix_voice
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :+bob\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("bob")
    assert_includes channel.users["bob"], :voice
  end

  def test_parse_multiple_prefixes
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :@+admin\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("admin")
    assert_includes channel.users["admin"], :op
    assert_includes channel.users["admin"], :voice
  end

  def test_parse_no_prefix
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :regular\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("regular")
    assert_empty channel.users["regular"]
  end

  def test_collect_until_endofnames
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    names_event = nil
    client.on(:names) { |event| names_event = event }

    message1 = Yaic::Message.parse(":server 353 mynick = #test :@op1 +voice1\r\n")
    client.handle_message(message1)

    assert_nil names_event

    message2 = Yaic::Message.parse(":server 353 mynick = #test :user2 user3\r\n")
    client.handle_message(message2)

    assert_nil names_event

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    refute_nil names_event
    assert_equal :names, names_event.type
    assert_equal "#test", names_event.channel

    channel = client.channels["#test"]
    assert_equal 4, channel.users.size
    assert channel.users.key?("op1")
    assert channel.users.key?("voice1")
    assert channel.users.key?("user2")
    assert channel.users.key?("user3")
  end

  def test_update_users_on_names
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    channel = client.channels["#test"]
    channel.users["olduser"] = Set.new

    message = Yaic::Message.parse(":server 353 mynick = #test :@newop\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    assert channel.users.key?("newop")
  end

  def test_halfop_prefix
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :%halfop\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("halfop")
    assert_includes channel.users["halfop"], :halfop
  end

  def test_owner_prefix
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :~owner\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("owner")
    assert_includes channel.users["owner"], :owner
  end

  def test_admin_prefix
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    message = Yaic::Message.parse(":server 353 mynick = #test :&admin\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    channel = client.channels["#test"]
    assert channel.users.key?("admin")
    assert_includes channel.users["admin"], :admin
  end

  def test_names_event_includes_users
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "mynick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    join_message = Yaic::Message.parse(":mynick!user@host JOIN #test\r\n")
    client.handle_message(join_message)

    names_event = nil
    client.on(:names) { |event| names_event = event }

    message = Yaic::Message.parse(":server 353 mynick = #test :@op +voice regular\r\n")
    client.handle_message(message)

    endofnames = Yaic::Message.parse(":server 366 mynick #test :End of /NAMES list.\r\n")
    client.handle_message(endofnames)

    refute_nil names_event
    assert_equal 3, names_event.users.size
    assert names_event.users.key?("op")
    assert names_event.users.key?("voice")
    assert names_event.users.key?("regular")
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
