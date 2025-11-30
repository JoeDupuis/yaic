# frozen_string_literal: true

require "test_helper"

class PrivmsgNoticeIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  parallelize_me!

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
    @test_nick2 = unique_nick("u")
    @test_channel = unique_channel
  end

  def test_send_privmsg_to_channel
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    client.privmsg(@test_channel, "Hello")
  ensure
    client&.quit
  end

  def test_send_privmsg_to_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    received_event = nil
    client2.on(:message) { |event| received_event = event }

    client1.privmsg(@test_nick2, "Hello")
    wait_until { received_event }

    refute_nil received_event
    assert_equal @test_nick, received_event.source.nick
    assert_equal @test_nick2, received_event.target
    assert_equal "Hello", received_event.text
  ensure
    client1&.quit
    client2&.quit
  end

  def test_send_notice_to_channel
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    client.notice(@test_channel, "Announcement")
  ensure
    client&.quit
  end

  def test_send_message_with_special_characters
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    client.privmsg(@test_channel, "Hello :) world")
  ensure
    client&.quit
  end

  def test_receive_privmsg_from_user
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    message_event = nil
    client1.on(:message) { |event| message_event = event }

    client2.privmsg(@test_nick, "hello from test")
    wait_until { message_event }

    refute_nil message_event
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_nick, message_event.target
    assert_equal "hello from test", message_event.text
  ensure
    client1&.quit
    client2&.quit
  end

  def test_receive_privmsg_in_channel
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    message_event = nil
    client1.on(:message) { |event| message_event = event }

    client2.privmsg(@test_channel, "hello channel")
    wait_until { message_event }

    refute_nil message_event
    assert_equal :message, message_event.type
    assert_equal @test_nick2, message_event.source.nick
    assert_equal @test_channel, message_event.target
    assert_equal "hello channel", message_event.text
  ensure
    client1&.quit
    client2&.quit
  end

  def test_receive_notice
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    notice_event = nil
    client1.on(:notice) { |event| notice_event = event }

    client2.notice(@test_nick, "FYI info here")
    wait_until { notice_event }

    refute_nil notice_event
    assert_equal :notice, notice_event.type
    assert_equal @test_nick2, notice_event.source.nick
    assert_equal @test_nick, notice_event.target
    assert_equal "FYI info here", notice_event.text
  ensure
    client1&.quit
    client2&.quit
  end

  def test_distinguish_channel_from_private_message
    client1 = create_connected_client(@test_nick)
    client2 = create_connected_client(@test_nick2)

    client1.join(@test_channel)
    client2.join(@test_channel)

    targets = []
    client1.on(:message) { |event| targets << event.target }

    client2.privmsg(@test_channel, "channel msg")
    client2.privmsg(@test_nick, "private msg")
    wait_until { targets.size >= 2 }

    assert_includes targets, @test_channel
    assert_includes targets, @test_nick
  ensure
    client1&.quit
    client2&.quit
  end

  def test_send_to_nonexistent_nick_receives_error
    client = create_connected_client(@test_nick)

    error_event = nil
    client.on(:error) { |event| error_event = event if event.numeric == 401 }

    client.privmsg("nonexistent_user_xyz_12345", "Hello")
    wait_until { error_event }

    refute_nil error_event
    assert_equal :error, error_event.type
    assert_equal 401, error_event.numeric
  ensure
    client&.quit
  end

  def test_send_to_channel_not_joined
    client = create_connected_client(@test_nick)

    error_event = nil
    client.on(:error) { |event| error_event = event if [403, 404].include?(event.numeric) }

    client.privmsg("#nonexistent_chan_xyz", "Hello")
    wait_until { error_event }

    refute_nil error_event
    assert_equal :error, error_event.type
    assert_includes [403, 404], error_event.numeric
  ensure
    client&.quit
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end

  def create_connected_client(nick)
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: nick,
      user: "testuser",
      realname: "Test User"
    )
    client.connect
    client
  end
end
