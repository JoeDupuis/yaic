# frozen_string_literal: true

require "test_helper"
require "stringio"

class VerboseIntegrationTest < Minitest::Test
  include UniqueTestIdentifiers

  def setup
    require_server_available
    @host = "localhost"
    @port = 6667
    @test_nick = unique_nick
    @test_nick2 = unique_nick("u")
    @test_channel = unique_channel
  end

  def test_verbose_mode_produces_expected_output_sequence
    output = StringIO.new
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User",
      verbose: true
    )
    client.instance_variable_set(:@verbose_output, output)
    def client.log(message)
      return unless @verbose
      @verbose_output.puts "[YAIC] #{message}"
    end

    client.connect
    client.join(@test_channel)
    client.who(@test_channel)
    client.quit

    log_output = output.string
    assert_includes log_output, "[YAIC] Connecting to #{@host}:#{@port}..."
    assert_includes log_output, "[YAIC] Connected"
    assert_includes log_output, "[YAIC] Joining #{@test_channel}..."
    assert_includes log_output, "[YAIC] Joined #{@test_channel}"
    assert_includes log_output, "[YAIC] Sending WHO #{@test_channel}..."
    assert_match(/\[YAIC\] WHO complete \(\d+ results\)/, log_output)
    assert_includes log_output, "[YAIC] Disconnected"
  end

  def test_verbose_false_produces_no_output
    output = StringIO.new
    client = Yaic::Client.new(
      host: @host,
      port: @port,
      nick: @test_nick,
      user: "testuser",
      realname: "Test User",
      verbose: false
    )
    client.instance_variable_set(:@verbose_output, output)
    def client.log(message)
      return unless @verbose
      @verbose_output.puts "[YAIC] #{message}"
    end

    client.connect
    client.join(@test_channel)
    client.quit

    assert_empty output.string
  end

  private

  def require_server_available
    TCPSocket.new(@host, 6667).close
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPERM
    flunk "IRC server not running. Start it with: bin/start-irc-server"
  end
end
