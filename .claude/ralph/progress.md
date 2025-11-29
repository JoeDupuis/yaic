# Progress Log

## Testing Rules

- **No skipping tests** unless it's for a feature we explicitly want to implement later (e.g., SSL tests pending infrastructure)
- Tests should **flunk** (fail) if prerequisites are missing (e.g., IRC server not running)
- A failing test means: either ask the user for help (start a server) or fix the code
- **No sleep in tests** - make tests fast and reliable
- Use unique generated nicknames for every test to avoid collisions

## Current State

Features 01, 02, 03, and 04 complete. Ready for `05-event-system.md`.

## Feature Order

Features should be implemented in this order (dependencies noted):

1. ~~`01-message-parsing.md`~~ ✅ - No deps, foundation for everything
2. ~~`02-connection-socket.md`~~ ✅ - Depends on 01
3. ~~`03-registration.md`~~ ✅ - Depends on 01, 02
4. ~~`04-ping-pong.md`~~ ✅ - Depends on 01, 02, 03
5. `05-event-system.md` - Depends on 01
6. `06-privmsg-notice.md` - Depends on 01-05
7. `07-join-part.md` - Depends on 01-05
8. `08-quit.md` - Depends on 01, 02, 05
9. `09-nick-change.md` - Depends on 01, 02, 03, 05
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

---

## Suggested Next Feature

Continue with `05-event-system.md` - Implements event callbacks for IRC events.
