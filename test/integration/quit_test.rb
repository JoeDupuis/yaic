# frozen_string_literal: true

require "test_helper"

class QuitIntegrationTest < Minitest::Test
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

  def test_quit_without_reason
    client = create_connected_client(@test_nick)
    client.quit
    assert_equal :disconnected, client.state
  end

  def test_quit_with_reason
    client = create_connected_client(@test_nick)
    client.quit("Bye!")
    assert_equal :disconnected, client.state
  end

  def test_receive_other_user_quit
    client1 = create_connected_client(@test_nick)
    client1.join(@test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    quit_event = nil
    client1.on(:quit) { |event| quit_event = event if event.user.nick == @test_nick2 }

    client2.quit("Leaving now")
    sleep 0.5

    refute_nil quit_event
    assert_equal :quit, quit_event.type
    assert_equal @test_nick2, quit_event.user.nick
  ensure
    client1&.quit
  end

  def test_detect_netsplit_quit
    client = create_connected_client(@test_nick)

    quit_event = nil
    client.on(:quit) { |event| quit_event = event }

    message = Yaic::Message.parse(":othernick!user@host QUIT :*.net *.split\r\n")
    client.handle_message(message)

    refute_nil quit_event
    assert_equal :quit, quit_event.type
    assert_equal "*.net *.split", quit_event.reason
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
