# frozen_string_literal: true

require "test_helper"

class NamesIntegrationTest < Minitest::Test
  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
    @test_nick2 = "u#{Process.pid}#{Time.now.to_i % 10000}"
    @test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
  end

  def test_get_names
    client = create_connected_client(@test_nick)
    client.join(@test_channel)

    names_event = nil
    client.on(:names) { |event| names_event = event }

    client.names(@test_channel)
    sleep 0.5

    refute_nil names_event
    channel = client.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have self in user list"
  ensure
    client&.quit
  end

  def test_names_with_prefixes
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)
    client2.join(@test_channel)

    names_event = nil
    client2.on(:names) { |event| names_event = event }

    client2.names(@test_channel)
    sleep 0.5

    refute_nil names_event
    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick)
    assert_includes channel.users[@test_nick], :op
  ensure
    client1&.quit
    client2&.quit
  end

  def test_names_at_join
    client1 = create_connected_client(@test_nick)
    socket1 = client1.instance_variable_get(:@socket)

    become_oper(socket1)

    client1.join(@test_channel)

    socket1.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket1, @test_channel)

    client2 = create_connected_client(@test_nick2)

    names_event = nil
    client2.on(:names) { |event| names_event = event }

    client2.join(@test_channel)

    refute_nil names_event
    channel = client2.channels[@test_channel]
    assert channel.users.key?(@test_nick), "Should have first user in list"
    assert channel.users.key?(@test_nick2), "Should have self in list"
    assert_includes channel.users[@test_nick], :op
  ensure
    client1&.quit
    client2&.quit
  end

  def test_multi_message_names
    client = create_connected_client(@test_nick)
    socket = client.instance_variable_get(:@socket)

    become_oper(socket)

    client.join(@test_channel)

    socket.write("SAMODE #{@test_channel} +o #{@test_nick}")
    wait_for_mode(socket, @test_channel)

    clients = []
    4.times do |i|
      nick = "x#{Process.pid}#{i}#{Time.now.to_i % 10000}"
      c = create_connected_client(nick)
      c.join(@test_channel)
      clients << c
    end

    names_event = nil
    client.on(:names) { |event| names_event = event }

    client.names(@test_channel)
    sleep 0.5

    refute_nil names_event
    channel = client.channels[@test_channel]
    assert channel.users.size >= 5, "Should have at least 5 users"
  ensure
    client&.quit
    clients&.each do |c|
      c&.quit
    end
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

  def wait_for_mode(socket, channel)
    start_time = Time.now
    loop do
      raw = socket.read
      break if raw&.include?("MODE") && raw.include?(channel)
      break if Time.now - start_time > 5
      sleep 0.01
    end
  end

  def become_oper(socket)
    socket.write("OPER testoper testpass")
    start_time = Time.now
    loop do
      raw = socket.read
      break if raw&.include?("381")
      break if Time.now - start_time > 5
      sleep 0.01
    end
  end
end
