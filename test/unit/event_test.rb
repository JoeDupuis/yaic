# frozen_string_literal: true

require "test_helper"

class EventTest < Minitest::Test
  def test_type_reader
    event = Yaic::Event.new(type: :message)
    assert_equal :message, event.type
  end

  def test_message_reader
    msg = Yaic::Message.parse(":nick!user@host PRIVMSG #test :hello\r\n")
    event = Yaic::Event.new(type: :message, message: msg)
    assert_equal msg, event.message
  end

  def test_attribute_access_via_method_missing
    event = Yaic::Event.new(type: :message, source: "nick", target: "#test", text: "hello")
    assert_equal "nick", event.source
    assert_equal "#test", event.target
    assert_equal "hello", event.text
  end

  def test_attribute_access_via_bracket
    event = Yaic::Event.new(type: :message, source: "nick", target: "#test")
    assert_equal "nick", event[:source]
    assert_equal "#test", event[:target]
  end

  def test_to_h_returns_attributes_copy
    event = Yaic::Event.new(type: :message, source: "nick", target: "#test")
    hash = event.to_h
    assert_equal({source: "nick", target: "#test"}, hash)
    hash[:foo] = "bar"
    assert_nil event[:foo]
  end

  def test_respond_to_for_attributes
    event = Yaic::Event.new(type: :message, source: "nick")
    assert event.respond_to?(:source)
    refute event.respond_to?(:nonexistent)
  end

  def test_method_missing_raises_for_unknown_attribute
    event = Yaic::Event.new(type: :message)
    assert_raises(NoMethodError) { event.nonexistent }
  end
end
