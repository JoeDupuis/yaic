# frozen_string_literal: true

require "test_helper"

class MessageSplitterTest < Minitest::Test
  def test_max_text_bytes_calculation
    result = Yaic::MessageSplitter.max_text_bytes(
      line_length: 512,
      command: "PRIVMSG",
      target: "#test"
    )
    assert_equal 495, result
  end

  def test_max_text_bytes_with_notice
    result = Yaic::MessageSplitter.max_text_bytes(
      line_length: 512,
      command: "NOTICE",
      target: "nick"
    )
    assert_equal 497, result
  end

  def test_max_text_bytes_with_prefix_length
    without_prefix = Yaic::MessageSplitter.max_text_bytes(
      line_length: 512,
      command: "PRIVMSG",
      target: "#test"
    )
    with_prefix = Yaic::MessageSplitter.max_text_bytes(
      line_length: 512,
      command: "PRIVMSG",
      target: "#test",
      prefix_length: 80
    )
    assert_equal without_prefix - 80, with_prefix
  end

  def test_max_text_bytes_never_below_one
    result = Yaic::MessageSplitter.max_text_bytes(
      line_length: 10,
      command: "PRIVMSG",
      target: "#very_long_channel_name"
    )
    assert_equal 1, result
  end

  def test_split_short_message_returns_single_element
    parts = Yaic::MessageSplitter.split("hello", max_bytes: 100)
    assert_equal ["hello"], parts
  end

  def test_split_exact_length_returns_single_element
    text = "a" * 100
    parts = Yaic::MessageSplitter.split(text, max_bytes: 100)
    assert_equal [text], parts
  end

  def test_split_long_message_into_multiple_parts
    text = "a" * 250
    parts = Yaic::MessageSplitter.split(text, max_bytes: 100)
    assert_equal 3, parts.size
    assert_equal 100, parts[0].bytesize
    assert_equal 100, parts[1].bytesize
    assert_equal 50, parts[2].bytesize
    assert_equal text, parts.join
  end

  def test_split_preserves_utf8
    text = "\u{1F600}" * 30
    parts = Yaic::MessageSplitter.split(text, max_bytes: 50)
    parts.each do |part|
      assert part.valid_encoding?, "Part should have valid encoding"
      assert part.bytesize <= 50, "Part should not exceed max_bytes"
    end
    assert_equal text, parts.join
  end

  def test_split_multibyte_boundary
    text = "aaa\u{1F600}bbb"
    parts = Yaic::MessageSplitter.split(text, max_bytes: 4)
    parts.each do |part|
      assert part.valid_encoding?, "Part should have valid encoding"
    end
    assert_equal text, parts.join
  end

  def test_split_empty_string
    parts = Yaic::MessageSplitter.split("", max_bytes: 100)
    assert_equal [""], parts
  end

  def test_split_with_max_bytes_of_one
    text = "abc"
    parts = Yaic::MessageSplitter.split(text, max_bytes: 1)
    assert_equal ["a", "b", "c"], parts
  end

  def test_split_breaks_when_character_exceeds_max_bytes
    parts = Yaic::MessageSplitter.split("\u{1F600}", max_bytes: 1)
    assert_equal [], parts
  end
end
