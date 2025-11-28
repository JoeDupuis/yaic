# frozen_string_literal: true

require "test_helper"

class SourceTest < Minitest::Test
  def test_parse_server_only
    source = Yaic::Source.parse("irc.example.com")

    assert_nil source.nick
    assert_equal "irc.example.com", source.host
  end

  def test_parse_full_user
    source = Yaic::Source.parse("dan!~d@localhost")

    assert_equal "dan", source.nick
    assert_equal "~d", source.user
    assert_equal "localhost", source.host
  end

  def test_parse_nick_only
    source = Yaic::Source.parse("dan")

    assert_equal "dan", source.nick
    assert_nil source.user
    assert_nil source.host
  end

  def test_parse_nick_and_host
    source = Yaic::Source.parse("dan@localhost")

    assert_equal "dan", source.nick
    assert_nil source.user
    assert_equal "localhost", source.host
  end

  def test_parse_nick_and_user
    source = Yaic::Source.parse("dan!~d")

    assert_equal "dan", source.nick
    assert_equal "~d", source.user
    assert_nil source.host
  end

  def test_stores_raw
    raw = "nick!user@host"
    source = Yaic::Source.parse(raw)

    assert_equal raw, source.raw
  end
end
