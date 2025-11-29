# Progress Log

## Testing Rules

- **No skipping tests** unless it's for a feature we explicitly want to implement later (e.g., SSL tests pending infrastructure)
- Tests should **flunk** (fail) if prerequisites are missing (e.g., IRC server not running)
- A failing test means: either ask the user for help (start a server) or fix the code
- **No sleep in tests** - make tests fast and reliable
- Use unique generated nicknames for every test to avoid collisions

## Current State

Features 01-09 complete. Ready for `10-topic.md`.

## Feature Order

Features should be implemented in this order (dependencies noted):

1. ~~`01-message-parsing.md`~~ ✅ - No deps, foundation for everything
2. ~~`02-connection-socket.md`~~ ✅ - Depends on 01
3. ~~`03-registration.md`~~ ✅ - Depends on 01, 02
4. ~~`04-ping-pong.md`~~ ✅ - Depends on 01, 02, 03
5. ~~`05-event-system.md`~~ ✅ - Depends on 01
6. ~~`06-privmsg-notice.md`~~ ✅ - Depends on 01-05
7. ~~`07-join-part.md`~~ ✅ - Depends on 01-05
8. ~~`08-quit.md`~~ ✅ - Depends on 01, 02, 05
9. ~~`09-nick-change.md`~~ ✅ - Depends on 01, 02, 03, 05
10. `10-topic.md` - Depends on 07
11. `11-kick.md` - Depends on 07
12. `12-names.md` - Depends on 07
13. `13-mode.md` - Depends on 07
14. `14-who-whois.md` - Depends on 01, 05
15. `15-client-api.md` - Depends on ALL (final integration)

---

## Session History

### Session 2025-11-28

**Feature**: 01-message-parsing
**Status**: Completed

**What was done**:
- Implemented `Yaic::Source` class with parsing for all source formats (server, nick!user@host, nick!user, nick@host, nick)
- Implemented `Yaic::Message` class with `parse` class method and `to_s` serialization
- Used StringScanner for efficient parsing
- Handled edge cases: LF-only line endings, empty lines, multiple spaces, UTF-8/Latin-1 encoding
- Created unit tests for both classes (21 tests, 40 assertions)
- All tests pass, linter clean, QA passed

**Notes for next session**:
- Message and Source classes are available via `require "yaic"`
- Public interface: `Yaic::Message.parse(str)`, `msg.to_s`, attribute readers (tags, source, command, params, raw)
- Public interface: `Yaic::Source.parse(str)`, attribute readers (nick, user, host, raw)

### Session 2025-11-28 (2)

**Feature**: 02-connection-socket
**Status**: Completed

**What was done**:
- Implemented `Yaic::Socket` class with TCP/SSL connection support
- Non-blocking connect with configurable timeout
- Read buffering with message extraction (handles \r\n and \n line endings)
- Write with automatic \r\n appending
- IPv4/IPv6 address resolution (prefers IPv4)
- Created `bin/start-irc-server` and `bin/stop-irc-server` for Docker container management
- Created `16-ssl-test-infrastructure.md` feature spec for future SSL testing
- Unit tests for buffer handling (6 tests)
- Integration tests for TCP connections (7 tests, 2 skipped for SSL)
- All tests pass, linter clean, QA passed

**Notes for next session**:
- Socket class available via `require "yaic"`
- Public interface: `Yaic::Socket.new(host, port, ssl:, verify_mode:, connect_timeout:)`, `connect`, `disconnect`, `read`, `write`, `state`
- SSL tests skip with message referencing `16-ssl-test-infrastructure.md`
- Integration tests require IRC server: run `bin/start-irc-server` first

### Session 2025-11-28 (3)

**Feature**: 03-registration
**Status**: Completed

**What was done**:
- Implemented `Yaic::Registration` module with message factory methods (pass_message, nick_message, user_message)
- Implemented `Yaic::Client` class with connection state machine (:disconnected → :connecting → :registering → :connected)
- Handles NICK/USER registration sequence, optional PASS command
- Handles RPL_WELCOME (001) to confirm registration
- Handles RPL_ISUPPORT (005) to parse server capabilities
- Handles ERR_NICKNAMEINUSE (433) with automatic nick retry (appends underscores)
- Created custom InspIRCd config (`test/fixtures/inspircd.conf`) to disable connection throttling
- Updated `bin/start-irc-server` to mount custom config
- Added RUBOCOP_CACHE_ROOT to devenv.nix
- Unit tests for message formatting (4 tests) and state machine (6 tests)
- Integration tests for registration flows (4 tests)
- All tests pass, linter clean, QA passed

**Deferred items**:
- Event emission for nick collision: Deferred to 05-event-system (event system not yet implemented)
- Password integration test: Deferred (test server not configured with password requirement)

**Notes for next session**:
- Registration module available via `require "yaic"`
- Public interface: `Yaic::Registration.pass_message(pw)`, `.nick_message(nick)`, `.user_message(user, realname)`
- Client class available via `require "yaic"`
- Public interface: `Yaic::Client.new(host:, port:, nick:, user:, realname:, password:, ssl:)`, `connect`, `disconnect`, `state`, `nick`, `isupport`
- Integration tests require IRC server: run `bin/start-irc-server` first

### Session 2025-11-28 (4)

**Feature**: 04-ping-pong
**Status**: Completed

**What was done**:
- Added PING handling to `Yaic::Client` class in `handle_message`
- Automatically responds to PING with PONG (token mirrored exactly)
- Works during registration and when connected
- Handles PING with or without colon prefix
- Added `STALE_TIMEOUT = 180` constant for connection timeout detection
- Added `last_received_at` attribute (updated on every message received)
- Added `connection_stale?` method to check if connection may be dead
- Reduced `pingfreq` in test server config from 120s to 5s for faster testing
- Unit tests for PING/PONG handling and connection staleness (8 tests)
- Integration tests including Client automatically responding to server-initiated PINGs (4 tests)
- All tests pass, linter clean, QA passed

**Notes for next session**:
- Client class now handles PING automatically in `handle_message`
- Public interface additions: `last_received_at`, `connection_stale?`
- PONG response uses Message class so spaces in token get proper `:` trailing prefix
- Integration tests now use 5-second ping frequency for fast testing

### Session 2025-11-28 (5)

**Feature**: 05-event-system
**Status**: Completed

**What was done**:
- Created `Yaic::Event` class with type, message, and dynamic attribute access via method_missing
- Added `on(event_type, &block)` and `off(event_type)` methods to Client for handler registration
- Implemented event dispatch with error handling (exceptions in handlers don't stop other handlers)
- Added `:raw` event emitted for every message received
- Added typed events: `:connect`, `:message`, `:notice`, `:join`, `:part`, `:quit`, `:kick`, `:nick`, `:topic`, `:mode`, `:error`
- Event payloads match spec (source, target, text, channel, user, etc.)
- Unit tests for Event class (7 tests)
- Unit tests for handler registration and dispatch (17 new tests in client_test.rb)
- Integration tests for connect, join, message, and raw events (4 tests)
- All tests pass, linter clean, QA passed

**Notes for next session**:
- Event class available via `require "yaic"`
- Public interface: `client.on(:event) { |e| ... }`, `client.off(:event)`
- Event object: `event.type`, `event.message`, `event.<attribute>` (dynamic access)
- `:disconnect` event not implemented (no event loop yet to detect disconnection)

### Session 2025-11-28 (6)

**Feature**: 06-privmsg-notice
**Status**: Completed

**What was done**:
- Added `privmsg(target, text)` method to Client for sending private messages
- Added `msg(target, text)` as alias for `privmsg`
- Added `notice(target, text)` method to Client for sending notices
- Modified Message#to_s to always use trailing prefix (`:`) for last param when multiple params exist
- Fixed pre-existing failing test in socket_test.rb (test assumed server sends message on connect)
- Unit tests for message formatting (PRIVMSG/NOTICE with special chars)
- Unit tests for event parsing (PRIVMSG/NOTICE events)
- Integration tests for sending to channels and users (4 tests)
- Integration tests for receiving messages and notices (4 tests)
- Integration tests for error handling (401 no such nick, 403/404 no such channel)
- All tests pass, linter clean, QA passed

**Notes for next session**:
- Public interface additions: `client.privmsg(target, text)`, `client.msg(target, text)`, `client.notice(target, text)`
- Message text always uses trailing prefix for proper formatting
- Error events emitted for 401/403/404 errors

### Session 2025-11-28 (7)

**Feature**: 07-join-part
**Status**: Completed

**What was done**:
- Created `Yaic::Channel` class for tracking joined channels
- Added `client.channels` hash to track which channels client is in
- Added `client.join(channel, key = nil)` method for joining channels
- Added `client.part(channel, reason = nil)` method for leaving channels
- Channel tracking: self-join adds channel, self-part removes channel
- Other users' JOIN/PART does not affect channel tracking (events still emitted)
- Fixed `Message#to_s` to only use trailing prefix when actually needed (spaces, empty, starts with colon)
- Updated server config to remove `+t` default mode so tests can set topics
- Unit tests for JOIN/PART formatting and event parsing (10 new tests)
- Integration tests for join, part, topics, multiple channels, events (11 tests)
- All tests pass (127 runs, 251 assertions, 2 SSL skips), linter clean, QA passed

**Notes for next session**:
- Channel class available via `require "yaic"`
- Public interface: `client.join(channel, key)`, `client.part(channel, reason)`, `client.channels`
- Channel object: `channel.name`, `channel.topic`, `channel.users`, `channel.modes` (users/modes not yet populated)
- Server config now uses `defaultmodes="n"` instead of `"nt"` to allow topic setting without +o

### Session 2025-11-28 (8)

**Feature**: 08-quit
**Status**: Completed

**What was done**:
- Added `client.quit(reason = nil)` method for gracefully disconnecting from server
- Sends `QUIT\r\n` (no reason) or `QUIT :reason\r\n` (with reason)
- Clears all tracked channels after quit
- Sets state to `:disconnected`
- Emits `:disconnect` event after quit
- Parses QUIT events from other users with `user` and `reason` attributes
- Unit tests for QUIT formatting, event parsing, state changes, channel cleanup (7 new tests)
- Integration tests for quit without/with reason, receiving other user quit, netsplit detection (4 tests)
- All tests pass (138 runs, 271 assertions, 2 SSL skips), linter clean, QA passed

**Notes for next session**:
- Public interface additions: `client.quit(reason = nil)`
- `:disconnect` event now implemented (emitted after quit)
- QUIT reason may be nil if server doesn't include one

### Session 2025-11-28 (9)

**Feature**: 09-nick-change
**Status**: Completed

**What was done**:
- Added `client.nick(new_nick)` method for changing nickname (sends `NICK new_nick\r\n`)
- Modified `nick` to work as both getter (no arg) and setter (with arg) - removed from attr_reader
- Added `handle_nick(message)` to update internal nick when self changes nick
- Added channel user list updates when any user changes nick (iterates all channels)
- Fixed `handle_err_nicknameinuse` to only auto-retry during registration (not when connected)
- Unit tests for NICK formatting, event parsing, own nick tracking, channel user tracking (5 new tests)
- Integration tests for nick change, nick in use, invalid nick, other user changes nick (4 tests)
- All tests pass (148 runs, 293 assertions, 2 SSL skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.nick` (getter), `client.nick("new")` (setter)
- `:nick` event emitted with `old_nick`, `new_nick` attributes
- Channel user tracking updates across all channels when nick changes
- 433 (nick in use) only auto-retries during registration state

---

## Suggested Next Feature

Continue with `10-topic.md` - Implements TOPIC command for getting/setting channel topics.
