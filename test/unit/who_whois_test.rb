# frozen_string_literal: true

require "test_helper"

class WhoWhoisTest < Minitest::Test
  def test_who_formats_correctly
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 testnick :Welcome\r\n"
    ]
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick", user: "testnick", realname: "Test")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 315 testnick #test :End of /WHO list.\r\n"
    ]
    mock_socket.trigger_post_connect
    client.who("#test")

    assert mock_socket.written.any? { |m| m == "WHO #test\r\n" }
  ensure
    client&.quit
  end

  def test_who_nick_formats_correctly
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 testnick :Welcome\r\n"
    ]
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick", user: "testnick", realname: "Test")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 315 testnick target :End of /WHO list.\r\n"
    ]
    mock_socket.trigger_post_connect
    client.who("target")

    assert mock_socket.written.any? { |m| m == "WHO target\r\n" }
  ensure
    client&.quit
  end

  def test_whois_formats_correctly
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 testnick :Welcome\r\n"
    ]
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick", user: "testnick", realname: "Test")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 318 testnick target :End of /WHOIS list.\r\n"
    ]
    mock_socket.trigger_post_connect
    client.whois("target")

    assert mock_socket.written.any? { |m| m == "WHOIS target\r\n" }
  ensure
    client&.quit
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

  def test_who_returns_array_of_who_results
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 352 me #chan ~user1 host1 srv nick1 H :0 Real Name 1\r\n",
      ":server 352 me #chan ~user2 host2 srv nick2 G :0 Real Name 2\r\n",
      ":server 315 me #chan :End of /WHO list.\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.who("#chan")

    assert_instance_of Array, results
    assert_equal 2, results.size
    assert_instance_of Yaic::WhoResult, results[0]
    assert_equal "nick1", results[0].nick
    assert_equal "~user1", results[0].user
    assert_equal "host1", results[0].host
    assert_equal "srv", results[0].server
    assert_equal "#chan", results[0].channel
    assert_equal false, results[0].away
    assert_equal "Real Name 1", results[0].realname

    assert_equal "nick2", results[1].nick
    assert_equal true, results[1].away
  ensure
    client&.quit
  end

  def test_who_returns_empty_array_when_no_matches
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 315 me nobody :End of /WHO list.\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.who("nobody")

    assert_instance_of Array, results
    assert_empty results
  ensure
    client&.quit
  end

  def test_who_raises_timeout_error_on_timeout
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]
    mock_socket.post_connect_responses = []

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    assert_raises(Yaic::TimeoutError) do
      client.who("#chan", timeout: 0.1)
    end
  ensure
    client&.quit
  end

  def test_who_still_emits_events
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    who_events = []
    client.on(:who) { |event| who_events << event }

    client.connect

    mock_socket.post_connect_responses = [
      ":server 352 me #chan ~user host srv nick H :0 Real Name\r\n",
      ":server 315 me #chan :End of /WHO list.\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.who("#chan")

    assert_equal 1, who_events.size
    assert_equal 1, results.size
    assert_equal "nick", who_events[0].nick
    assert_equal "nick", results[0].nick
  ensure
    client&.quit
  end

  def test_whois_returns_whois_result
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 311 me nick ~user host * :Real Name\r\n",
      ":server 312 me nick irc.example.org :Server Info\r\n",
      ":server 318 me nick :End of /WHOIS list.\r\n"
    ]
    mock_socket.trigger_post_connect

    result = client.whois("nick")

    assert_instance_of Yaic::WhoisResult, result
    assert_equal "nick", result.nick
    assert_equal "~user", result.user
    assert_equal "host", result.host
    assert_equal "Real Name", result.realname
    assert_equal "irc.example.org", result.server
  ensure
    client&.quit
  end

  def test_whois_returns_nil_for_unknown_nick
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 401 me nobody :No such nick/channel\r\n",
      ":server 318 me nobody :End of /WHOIS list.\r\n"
    ]
    mock_socket.trigger_post_connect

    result = client.whois("nobody")

    assert_nil result
  ensure
    client&.quit
  end

  def test_whois_raises_timeout_error_on_timeout
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]
    mock_socket.post_connect_responses = []

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    assert_raises(Yaic::TimeoutError) do
      client.whois("nick", timeout: 0.1)
    end
  ensure
    client&.quit
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

  class BlockingMockSocket
    attr_accessor :responses, :post_connect_responses
    attr_reader :written, :state

    def initialize
      @written = []
      @responses = []
      @post_connect_responses = []
      @state = :disconnected
      @response_index = 0
      @post_connect_triggered = false
      @mutex = Mutex.new
    end

    def connect
      @state = :connecting
    end

    def disconnect
      @state = :disconnected
    end

    def write(message)
      @mutex.synchronize do
        @written << message.to_s
      end
    end

    def read
      @mutex.synchronize do
        if @response_index < @responses.size
          msg = @responses[@response_index]
          @response_index += 1
          msg
        elsif @post_connect_triggered && @post_connect_responses.any?
          @post_connect_responses.shift
        end
      end
    end

    def trigger_post_connect
      @mutex.synchronize do
        @post_connect_triggered = true
      end
    end
  end
end
