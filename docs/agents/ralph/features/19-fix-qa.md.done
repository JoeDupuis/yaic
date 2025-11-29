Look at 02-simplified-client-api.md.done
An agent flag that feature as done without the QA passing on it. Which is TOTALLY UNACCEPTABLE.

Do not rerun QA before you're ready to commit. I'll give you the QA output:

```
  QA FAILED. Issues found:

       1. Public timeout parameters violate feature spec (/Users/joedupuis/workspace/yaic/lib/yaic/client.rb lines
       55, 159, 166, 184):
         - The feature spec at
       /Users/joedupuis/workspace/yaic/docs/agents/ralph/features/02-simplified-client-api.md.done explicitly
       states:
             - Line 32: "All methods block until the operation completes. No bangs, no timeout params, no manual
       socket handling."
           - Lines 86-90: "Timeouts are an internal concern. Use sensible defaults... Users don't need to think
       about this."
         - However, the implementation exposes timeout: keyword arguments in the public API:
         def connect(timeout: DEFAULT_CONNECT_TIMEOUT)
       def join(channel, key = nil, timeout: DEFAULT_OPERATION_TIMEOUT)
       def part(channel, reason = nil, timeout: DEFAULT_OPERATION_TIMEOUT)
       def nick(new_nick = nil, timeout: DEFAULT_OPERATION_TIMEOUT)
         - Fix: Remove the public timeout: parameter from these method signatures. Keep the internal constants and
       use them directly in wait_until.
       2. Integration tests still use instance_variable_get(:@socket) (Multiple files):
         - /Users/joedupuis/workspace/yaic/test/integration/mode_test.rb lines 79, 103, 130
         - /Users/joedupuis/workspace/yaic/test/integration/kick_test.rb lines 17, 43, 88, 110, 146
         - /Users/joedupuis/workspace/yaic/test/integration/names_test.rb lines 34, 63, 91
         - /Users/joedupuis/workspace/yaic/test/integration/nick_test.rb lines 33, 51
         - /Users/joedupuis/workspace/yaic/test/integration/join_part_test.rb lines 53, 108
         - /Users/joedupuis/workspace/yaic/test/integration/who_whois_test.rb line 133
         - The feature spec (lines 136-139) explicitly says to remove:
             - instance_variable_get
           - Manual read loops
           - Custom wait helpers
           - on_socket_connected
         - These tests use instance_variable_get(:@socket) to call become_oper and send raw commands like OPER and
       SAMODE.
         - Fix: Either add a public raw or send_raw method to the Client class for sending raw IRC commands, or
       refactor the tests to not require OPER privileges (if possible). The become_oper helper pattern using direct
        socket access is exactly what the feature was meant to eliminate.

       Required fixes:
       1. Remove timeout: parameter from the public method signatures of connect, join, part, and nick.
       2. Either add a public raw(command) method to send arbitrary IRC commands, or refactor integration tests
       that need OPER privileges to avoid accessing internal socket.
```

and

```
  Two issues found:

  1. Public timeout parameters violate feature spec - The methods connect, join, part, and nick expose timeout:
  keyword arguments, but the feature spec explicitly states "No bangs, no timeout params" and "Timeouts are an
  internal concern."
  2. Integration tests still use instance_variable_get(:@socket) - Multiple integration tests access the internal
  socket directly via instance_variable_get(:@socket) to call become_oper and send raw commands. The feature spec
  says to remove this pattern.

  Required fixes:
  1. Remove timeout: parameter from public method signatures
  2. Add a public raw(command) method for sending arbitrary IRC commands, or refactor the tests
```


Fix the mess. If you cant stop and ask me questions.


I think the timeout is fine. Let's ignore the first part. The second part though with the reaching for instance variable is bad.
The tests should not have to reach out for internals with instance_variable_get.

If you are blocked ask me with the ask question tool.
