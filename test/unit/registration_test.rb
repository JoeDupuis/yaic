# frozen_string_literal: true

require "test_helper"

class RegistrationTest < Minitest::Test
  def test_format_pass_command
    msg = Yaic::Registration.pass_message("secret")
    assert_equal "PASS secret\r\n", msg.to_s
  end

  def test_format_nick_command
    msg = Yaic::Registration.nick_message("mynick")
    assert_equal "NICK mynick\r\n", msg.to_s
  end

  def test_format_user_command
    msg = Yaic::Registration.user_message("myuser", "My Real Name")
    assert_equal "USER myuser 0 * :My Real Name\r\n", msg.to_s
  end

  def test_format_user_command_with_empty_realname
    msg = Yaic::Registration.user_message("myuser", "")
    assert_equal "USER myuser 0 * :\r\n", msg.to_s
  end
end
