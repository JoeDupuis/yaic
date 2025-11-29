# frozen_string_literal: true

require_relative "yaic/version"
require_relative "yaic/source"
require_relative "yaic/message"
require_relative "yaic/socket"
require_relative "yaic/registration"
require_relative "yaic/event"
require_relative "yaic/channel"
require_relative "yaic/whois_result"
require_relative "yaic/client"

module Yaic
  class Error < StandardError; end
  class TimeoutError < Error; end
end
