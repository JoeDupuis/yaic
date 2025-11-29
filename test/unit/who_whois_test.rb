# frozen_string_literal: true

require "test_helper"

class WhoWhoisTest < Minitest::Test
  def test_who_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.who("#test")

    assert_equal "WHO #test\r\n", mock_socket.written.last
  end

  def test_who_nick_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.who("target")

    assert_equal "WHO target\r\n", mock_socket.written.last
  end

  def test_whois_formats_correctly
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    client.whois("target")

    assert_equal "WHOIS target\r\n", mock_socket.written.last
  end

  def test_parse_rpl_whoreply_basic
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    who_event = nil
    client.on(:who) { |event| who_event = event }

    message = Yaic::Message.parse(":server 352 me #chan ~user host srv nick H :0 Real Name\r\n")
    client.handle_message(message)

    refute_nil who_event
    assert_equal "#chan", who_event.channel
    assert_equal "~user", who_event.user
    assert_equal "host", who_event.host
    assert_equal "srv", who_event.server
    assert_equal "nick", who_event.nick
    assert_equal false, who_event.away
    assert_equal "Real Name", who_event.realname
  end

  def test_parse_rpl_whoreply_away
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    who_event = nil
    client.on(:who) { |event| who_event = event }

    message = Yaic::Message.parse(":server 352 me #chan ~user host srv nick G :0 Name\r\n")
    client.handle_message(message)

    refute_nil who_event
    assert_equal true, who_event.away
  end

  def test_parse_rpl_whoreply_star_channel
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    who_event = nil
    client.on(:who) { |event| who_event = event }

    message = Yaic::Message.parse(":server 352 me * ~user host srv nick H :0 Name\r\n")
    client.handle_message(message)

    refute_nil who_event
    assert_equal "*", who_event.channel
  end

  def test_parse_rpl_whoisuser
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    message = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    refute_nil result
    assert_equal "nick", result.nick
    assert_equal "~user", result.user
    assert_equal "host", result.host
    assert_equal "Real Name", result.realname
  end

  def test_parse_rpl_whoischannels
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    message = Yaic::Message.parse(":server 319 me nick :#chan1 @#chan2 +#chan3\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    assert_includes result.channels, "#chan1"
    assert_includes result.channels, "#chan2"
    assert_includes result.channels, "#chan3"
  end

  def test_parse_rpl_whoisidle
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    message = Yaic::Message.parse(":server 317 me nick 300 1234567890 :seconds idle\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    assert_equal 300, result.idle
    assert_equal Time.at(1234567890), result.signon
  end

  def test_parse_rpl_whoisaccount
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    message = Yaic::Message.parse(":server 330 me nick account :is logged in as\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    assert_equal "account", result.account
  end

  def test_parse_rpl_whoisserver
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    message = Yaic::Message.parse(":server 312 me nick irc.example.org :Server Info\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    assert_equal "irc.example.org", result.server
  end

  def test_parse_rpl_away
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    message = Yaic::Message.parse(":server 301 me nick :I am away\r\n")
    client.handle_message(message)

    pending_whois = client.instance_variable_get(:@pending_whois)
    result = pending_whois["nick"]
    assert_equal "I am away", result.away
  end

  def test_collect_whois_parts
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    whois_event = nil
    client.on(:whois) { |event| whois_event = event }

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    channels_msg = Yaic::Message.parse(":server 319 me nick :#chan1 @#chan2\r\n")
    client.handle_message(channels_msg)

    server_msg = Yaic::Message.parse(":server 312 me nick irc.example.org :Server Info\r\n")
    client.handle_message(server_msg)

    assert_nil whois_event

    end_msg = Yaic::Message.parse(":server 318 me nick :End of /WHOIS list.\r\n")
    client.handle_message(end_msg)

    refute_nil whois_event
    assert_equal :whois, whois_event.type
    assert_equal "nick", whois_event.result.nick
    assert_equal "~user", whois_event.result.user
    assert_equal "host", whois_event.result.host
    assert_equal "Real Name", whois_event.result.realname
    assert_equal "irc.example.org", whois_event.result.server
    assert_includes whois_event.result.channels, "#chan1"
    assert_includes whois_event.result.channels, "#chan2"
  end

  def test_handle_interleaved_messages
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    whois_event = nil
    client.on(:whois) { |event| whois_event = event }

    user_msg = Yaic::Message.parse(":server 311 me nick ~user host * :Real Name\r\n")
    client.handle_message(user_msg)

    privmsg = Yaic::Message.parse(":other!user@host PRIVMSG me :hello\r\n")
    client.handle_message(privmsg)

    channels_msg = Yaic::Message.parse(":server 319 me nick :#chan1\r\n")
    client.handle_message(channels_msg)

    ping_msg = Yaic::Message.parse("PING :server\r\n")
    client.handle_message(ping_msg)

    end_msg = Yaic::Message.parse(":server 318 me nick :End of /WHOIS list.\r\n")
    client.handle_message(end_msg)

    refute_nil whois_event
    assert_equal "nick", whois_event.result.nick
    assert_includes whois_event.result.channels, "#chan1"
  end

  def test_who_event_emitted_on_endofwho
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    who_replies = []
    client.on(:who) { |event| who_replies << event }

    message = Yaic::Message.parse(":server 352 me #chan ~user host srv nick H :0 Real Name\r\n")
    client.handle_message(message)

    assert_equal 1, who_replies.size

    end_msg = Yaic::Message.parse(":server 315 me #chan :End of /WHO list.\r\n")
    client.handle_message(end_msg)

    assert_equal 1, who_replies.size
  end

  def test_whois_nosuchnick
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    error_event = nil
    whois_event = nil
    client.on(:error) { |event| error_event = event }
    client.on(:whois) { |event| whois_event = event }

    message = Yaic::Message.parse(":server 401 me nobody :No such nick/channel\r\n")
    client.handle_message(message)

    refute_nil error_event
    assert_equal 401, error_event.numeric

    end_msg = Yaic::Message.parse(":server 318 me nobody :End of /WHOIS list.\r\n")
    client.handle_message(end_msg)

    refute_nil whois_event
    assert_nil whois_event.result
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
