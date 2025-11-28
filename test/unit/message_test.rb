# frozen_string_literal: true

require "test_helper"

class MessageTest < Minitest::Test
  def test_parse_simple_command
    msg = Yaic::Message.parse("PING :token123\r\n")

    assert_equal "PING", msg.command
    assert_equal ["token123"], msg.params
  end

  def test_parse_message_with_source
    msg = Yaic::Message.parse(":nick!user@host PRIVMSG #channel :Hello world\r\n")

    assert_equal "nick", msg.source.nick
    assert_equal "user", msg.source.user
    assert_equal "host", msg.source.host
    assert_equal "PRIVMSG", msg.command
    assert_equal ["#channel", "Hello world"], msg.params
  end

  def test_parse_message_with_tags
    msg = Yaic::Message.parse("@id=123;time=2023-01-01 :server NOTICE * :Hello\r\n")

    assert_equal({"id" => "123", "time" => "2023-01-01"}, msg.tags)
    assert_equal "server", msg.source.raw
  end

  def test_parse_numeric_reply
    msg = Yaic::Message.parse(":irc.example.com 001 mynick :Welcome\r\n")

    assert_equal "001", msg.command
    assert_equal ["mynick", "Welcome"], msg.params
  end

  def test_parse_message_with_empty_trailing
    msg = Yaic::Message.parse(":server CAP * LIST :\r\n")

    assert_equal ["*", "LIST", ""], msg.params
  end

  def test_parse_message_with_colon_in_trailing
    msg = Yaic::Message.parse(":nick PRIVMSG #chan ::-)\r\n")

    assert_equal ["#chan", ":-)"], msg.params
  end

  def test_parse_message_without_trailing_colon
    msg = Yaic::Message.parse("NICK newnick\r\n")

    assert_equal "NICK", msg.command
    assert_equal ["newnick"], msg.params
  end

  def test_serialize_simple_command
    msg = Yaic::Message.new(command: "NICK", params: ["mynick"])

    assert_equal "NICK mynick\r\n", msg.to_s
  end

  def test_serialize_with_trailing_spaces
    msg = Yaic::Message.new(command: "PRIVMSG", params: ["#chan", "Hello world"])

    assert_equal "PRIVMSG #chan :Hello world\r\n", msg.to_s
  end

  def test_serialize_with_empty_trailing
    msg = Yaic::Message.new(command: "TOPIC", params: ["#chan", ""])

    assert_equal "TOPIC #chan :\r\n", msg.to_s
  end

  def test_never_include_source_in_client_messages
    source = Yaic::Source.new(nick: "test")
    msg = Yaic::Message.new(source: source, command: "NICK", params: ["test"])

    assert_equal "NICK test\r\n", msg.to_s
  end

  def test_handle_lf_only_line_endings
    msg = Yaic::Message.parse("PING :test\n")

    assert_equal "PING", msg.command
    assert_equal ["test"], msg.params
  end

  def test_ignore_empty_lines
    msg = Yaic::Message.parse("\r\n")

    assert_nil msg
  end

  def test_handle_multiple_spaces_between_components
    msg = Yaic::Message.parse(":server  PRIVMSG  #chan  :text\r\n")

    assert_equal "PRIVMSG", msg.command
    assert_equal ["#chan", "text"], msg.params
  end

  def test_stores_raw_message
    raw = ":nick!user@host PRIVMSG #channel :Hello\r\n"
    msg = Yaic::Message.parse(raw)

    assert_equal raw, msg.raw
  end
end
