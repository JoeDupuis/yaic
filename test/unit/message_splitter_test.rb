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

  def test_split_prefers_word_boundary
    parts = Yaic::MessageSplitter.split("hello world foo bar", max_bytes: 11)
    assert_equal ["hello world", "foo bar"], parts
  end

  def test_split_word_boundary_consumes_space
    parts = Yaic::MessageSplitter.split("aaa bbb", max_bytes: 4)
    assert_equal ["aaa", "bbb"], parts
  end

  def test_split_falls_back_to_byte_cut_when_no_space
    url = "https://example.com/very/long/path"
    parts = Yaic::MessageSplitter.split(url, max_bytes: 20)
    parts.each do |part|
      assert part.bytesize <= 20
    end
    assert_equal url, parts.join
  end

  def test_split_long_url_without_spaces
    url = "a" * 50
    parts = Yaic::MessageSplitter.split(url, max_bytes: 20)
    assert_equal 3, parts.size
    assert_equal ["a" * 20, "a" * 20, "a" * 10], parts
  end

  def test_split_mixed_words_then_long_token
    text = "hi " + "x" * 20
    parts = Yaic::MessageSplitter.split(text, max_bytes: 10)
    assert_equal ["hi", "x" * 10, "x" * 10], parts
  end

  def test_split_multiple_consecutive_spaces
    parts = Yaic::MessageSplitter.split("aaa  bbb", max_bytes: 5)
    assert_equal ["aaa ", "bbb"], parts
  end

  def test_split_word_boundary_with_utf8
    text = "\u{1F600} hello world"
    parts = Yaic::MessageSplitter.split(text, max_bytes: 10)
    parts.each do |part|
      assert part.valid_encoding?, "Part should have valid encoding"
      assert part.bytesize <= 10
    end
    assert_equal text, parts.join(" ")
  end

  def test_split_space_at_exact_boundary
    parts = Yaic::MessageSplitter.split("abcde fghij", max_bytes: 5)
    assert_equal ["abcde", "fghij"], parts
  end

  def test_split_all_content_reassembles
    text = "the quick brown fox jumps over the lazy dog"
    parts = Yaic::MessageSplitter.split(text, max_bytes: 10)
    assert_equal text, parts.join(" ")
    parts.each do |part|
      assert part.bytesize <= 10
    end
  end
end
