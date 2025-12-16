# frozen_string_literal: true

require "test_helper"

class IsonTest < Minitest::Test
  def test_ison_formats_correctly
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 testnick :Welcome\r\n"
    ]
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick", user: "testnick", realname: "Test")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 303 testnick :nick1 nick2\r\n"
    ]
    mock_socket.trigger_post_connect
    client.ison("nick1", "nick2", "nick3")

    assert mock_socket.written.any? { |m| m == "ISON :nick1 nick2 nick3\r\n" }
  ensure
    client&.quit
  end

  def test_ison_accepts_array
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 testnick :Welcome\r\n"
    ]
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "testnick", user: "testnick", realname: "Test")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 303 testnick :nick1\r\n"
    ]
    mock_socket.trigger_post_connect
    client.ison(["nick1", "nick2"])

    assert mock_socket.written.any? { |m| m == "ISON :nick1 nick2\r\n" }
  ensure
    client&.quit
  end

  def test_ison_returns_online_nicks
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 303 me :nick1 nick3\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.ison("nick1", "nick2", "nick3")

    assert_instance_of Array, results
    assert_equal 2, results.size
    assert_includes results, "nick1"
    assert_includes results, "nick3"
    refute_includes results, "nick2"
  ensure
    client&.quit
  end

  def test_ison_returns_empty_array_when_none_online
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    mock_socket.post_connect_responses = [
      ":server 303 me :\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.ison("nick1", "nick2")

    assert_instance_of Array, results
    assert_empty results
  ensure
    client&.quit
  end

  def test_ison_returns_empty_array_for_empty_input
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    results = client.ison

    assert_instance_of Array, results
    assert_empty results
  end

  def test_ison_emits_event
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    ison_event = nil
    client.on(:ison) { |event| ison_event = event }

    message = Yaic::Message.parse(":server 303 me :nick1 nick2\r\n")
    client.handle_message(message)

    refute_nil ison_event
    assert_equal :ison, ison_event.type
    assert_includes ison_event.nicks, "nick1"
    assert_includes ison_event.nicks, "nick2"
  end

  def test_ison_emits_event_with_empty_nicks
    mock_socket = MockSocket.new
    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me")
    client.instance_variable_set(:@socket, mock_socket)
    client.instance_variable_set(:@state, :connected)

    ison_event = nil
    client.on(:ison) { |event| ison_event = event }

    message = Yaic::Message.parse(":server 303 me :\r\n")
    client.handle_message(message)

    refute_nil ison_event
    assert_equal :ison, ison_event.type
    assert_empty ison_event.nicks
  end

  def test_ison_raises_timeout_error_on_timeout
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]
    mock_socket.post_connect_responses = []

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    client.connect

    assert_raises(Yaic::TimeoutError) do
      client.ison("nick1", timeout: 0.1)
    end
  ensure
    client&.quit
  end

  def test_ison_still_emits_events
    mock_socket = BlockingMockSocket.new
    mock_socket.responses = [
      ":server 001 me :Welcome\r\n"
    ]

    client = Yaic::Client.new(host: "localhost", port: 6667, nick: "me", user: "me", realname: "Me")
    client.instance_variable_set(:@socket, mock_socket)

    ison_events = []
    client.on(:ison) { |event| ison_events << event }

    client.connect

    mock_socket.post_connect_responses = [
      ":server 303 me :nick1\r\n"
    ]
    mock_socket.trigger_post_connect

    results = client.ison("nick1", "nick2")

    assert_equal 1, ison_events.size
    assert_equal 1, results.size
    assert_includes ison_events[0].nicks, "nick1"
    assert_includes results, "nick1"
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
