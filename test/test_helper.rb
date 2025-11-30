# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "yaic"

require "minitest/autorun"

module UniqueTestIdentifiers
  def unique_nick(prefix = "t")
    "#{prefix}#{Process.pid % 10000}#{Thread.current.object_id % 10000}#{rand(10000)}"
  end

  def unique_channel(prefix = "#test")
    "#{prefix}#{Process.pid % 10000}#{Thread.current.object_id % 10000}#{rand(10000)}"
  end

  def wait_until(timeout: 2)
    deadline = Time.now + timeout
    until Time.now > deadline
      result = yield
      return result if result
      sleep 0.01
    end
    nil
  end
end
