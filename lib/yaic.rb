# frozen_string_literal: true

require_relative "yaic/version"
require_relative "yaic/source"
require_relative "yaic/message"
require_relative "yaic/socket"

module Yaic
  class Error < StandardError; end
end
