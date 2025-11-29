# frozen_string_literal: true

require "test_helper"

class SocketTest < Minitest::Test
  def test_buffer_accumulates_partial_messages
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.instance_variable_set(:@state, :connected)

    socket.send(:buffer_data, "PING")
    assert_nil socket.send(:extract_message)

    socket.send(:buffer_data, " :test")
    assert_nil socket.send(:extract_message)

    socket.send(:buffer_data, "\r\n")
    assert_equal "PING :test\r\n", socket.send(:extract_message)
  end

  def test_multiple_messages_in_one_read
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.instance_variable_set(:@state, :connected)

    socket.send(:buffer_data, "MSG1\r\nMSG2\r\n")

    assert_equal "MSG1\r\n", socket.send(:extract_message)
    assert_equal "MSG2\r\n", socket.send(:extract_message)
    assert_nil socket.send(:extract_message)
  end

  def test_handle_lf_only_endings
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    socket.instance_variable_set(:@state, :connected)

    socket.send(:buffer_data, "PING :test\n")
    assert_equal "PING :test\n", socket.send(:extract_message)
  end

  def test_buffer_is_binary_string
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    buffer = socket.instance_variable_get(:@read_buffer)
    assert_equal Encoding::ASCII_8BIT, buffer.encoding
  end

  def test_initial_state_is_disconnected
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    assert_equal :disconnected, socket.state
  end

  def test_write_queue_starts_empty
    socket = Yaic::Socket.new("localhost", 6667, ssl: false)
    queue = socket.instance_variable_get(:@write_queue)
    assert_empty queue
  end
end
