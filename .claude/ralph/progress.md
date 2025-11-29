# Progress Log

## Current State

Features 01 and 02 complete. Ready for `03-registration.md`.

## Feature Order

Features should be implemented in this order (dependencies noted):

1. ~~`01-message-parsing.md`~~ ✅ - No deps, foundation for everything
2. ~~`02-connection-socket.md`~~ ✅ - Depends on 01
3. `03-registration.md` - Depends on 01, 02
4. `04-ping-pong.md` - Depends on 01, 02, 03
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

---

## Suggested Next Feature

Continue with `03-registration.md` - Implements IRC registration (NICK, USER, CAP negotiation).
