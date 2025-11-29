# frozen_string_literal: true

module Yaic
  module Registration
    def self.pass_message(password)
      Message.new(command: "PASS", params: [password])
    end

    def self.nick_message(nickname)
      Message.new(command: "NICK", params: [nickname])
    end

    def self.user_message(username, realname)
      Message.new(command: "USER", params: [username, "0", "*", realname])
    end
  end
end
