# Progress Log

## Testing Rules

- **No skipping tests** unless it's for a feature we explicitly want to implement later (e.g., SSL tests pending infrastructure)
- Tests should **flunk** (fail) if prerequisites are missing (e.g., IRC server not running)
- A failing test means: either ask the user for help (start a server) or fix the code
- **No sleep in tests** - make tests fast and reliable
- Use unique generated nicknames for every test to avoid collisions

## Current State

Features 01-17 complete. CI now runs on push to main and PRs.

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
10. ~~`10-topic.md`~~ ✅ - Depends on 07
11. ~~`11-kick.md`~~ ✅ - Depends on 07
12. ~~`12-names.md`~~ ✅ - Depends on 07
13. ~~`13-mode.md`~~ ✅ - Depends on 07
14. ~~`14-who-whois.md`~~ ✅ - Depends on 01, 05
15. ~~`15-client-api.md`~~ ✅ - Depends on ALL (final integration)
16. ~~`16-ssl-test-infrastructure.md`~~ ✅ - Depends on 02 (SSL testing)

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

### Session 2025-11-28 (10)

**Feature**: 10-topic
**Status**: Completed

**What was done**:
- Added `client.topic(channel, new_topic = nil)` method for getting/setting topics
- Added `set_topic(topic, setter, time)` method to Channel class
- Added handlers for TOPIC command, 332 (RPL_TOPIC), 333 (RPL_TOPICWHOTIME)
- Topic changes update channel.topic, channel.topic_setter, channel.topic_time
- `:topic` event emitted with channel, topic, setter attributes
- Modified Message#to_s to always use trailing prefix for last param when 2+ params (better IRC compliance)
- Unit tests for TOPIC formatting, parsing, channel state tracking (8 new tests)
- Integration tests for get topic, get no topic, set topic, clear topic, receive topic change (5 tests)
- 1 integration test skipped (set topic without permission) due to InspIRCd 4 not auto-opping channel creators
- All tests pass (161 runs, 319 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.topic(channel)` (get), `client.topic(channel, text)` (set), `client.topic(channel, "")` (clear)
- Channel object now has: `topic`, `topic_setter`, `topic_time` attributes
- Message#to_s now always uses trailing prefix for multi-param messages (proper IRC format)
- InspIRCd 4 limitation: users aren't auto-opped when creating channels, affecting +t mode tests

### Session 2025-11-29 (11)

**Feature**: 11-kick
**Status**: Completed

**What was done**:
- Added `client.kick(channel, nick, reason = nil)` method for kicking users from channels
- Added `handle_kick(message)` to update channel state (remove kicked user from channel, remove channel when self is kicked)
- Added KICK to handle_message dispatch
- Updated InspIRCd config to add `samode` module for server operator channel mode control
- Added `oper` block to InspIRCd config for test authentication
- Unit tests for KICK formatting and event parsing (6 new tests)
- Integration tests for kick user, kick with reason, kick without permission, kick non-existent user, receive kick others, receive kick self (6 tests)
- All tests pass (172 runs, 345 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.kick(channel, nick)`, `client.kick(channel, nick, reason)`
- `:kick` event emitted with `channel`, `user`, `by`, `reason` attributes
- State tracking: kicked user removed from channel.users, channel removed from client.channels when self is kicked
- InspIRCd test server now has oper credentials (testoper/testpass) and SAMODE for setting channel ops

### Session 2025-11-29 (12)

**Feature**: 12-names
**Status**: Completed

**What was done**:
- Added `client.names(channel)` method for requesting channel user lists
- Added `handle_rpl_namreply(message)` to collect users from 353 replies
- Added `handle_rpl_endofnames(message)` to finalize and emit `:names` event
- Added `parse_user_with_prefix(user_entry)` to parse user mode prefixes
- Added `PREFIX_MODES` constant mapping @, +, %, ~, & to :op, :voice, :halfop, :owner, :admin
- Added `@pending_names` hash to accumulate users across multiple 353 messages
- Users populated into `channel.users` as `Hash[String, Set[Symbol]]`
- `:names` event emitted with `channel:` and `users:` attributes
- Unit tests for NAMES formatting, prefix parsing, multi-message collection (12 tests)
- Integration tests for get names, names with prefixes, names at join, multi-message names (4 tests)
- All tests pass (189 runs, 400 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.names(channel)`
- `:names` event emitted with `channel:` (String) and `users:` (Hash[String, Set[Symbol]])
- `channel.users` is populated from NAMES responses
- Prefix parsing handles @op, +voice, %halfop, ~owner, &admin and multiple prefixes

### Session 2025-11-28 (13)

**Feature**: 13-mode
**Status**: Completed

**What was done**:
- Added `client.mode(target, modes = nil, *args)` method for querying/setting modes
- Added `handle_mode(message)` to parse MODE messages and update channel state
- Added `apply_user_mode(channel, nick, mode_char, adding)` for user mode tracking
- Channel mode tracking: moderated, invite_only, key, limit, topic_protected, no_external, secret, private
- User mode tracking in channels: op, voice, halfop, admin, owner
- Correctly parses +/- mode prefixes and handles mode parameters
- Unit tests for MODE formatting, event parsing, channel/user state tracking (14 new tests)
- Integration tests for user modes (get own, set invisible, cannot set other's) and channel modes (get, set as op, give op, set key, without permission) (8 tests)
- All tests pass (209 runs, 429 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.mode(target)` (query), `client.mode(target, modes)` (set), `client.mode(target, modes, *args)` (set with params)
- `:mode` event emitted with `target`, `modes`, `args` attributes
- `channel.modes` is a Hash[Symbol, Object] with keys like :moderated, :key, :limit
- User modes tracked in `channel.users[nick]` as Set of symbols (:op, :voice, etc.)

### Session 2025-11-29 (14)

**Feature**: 14-who-whois
**Status**: Completed

**What was done**:
- Created `Yaic::WhoisResult` class for aggregating WHOIS data
- Added `client.who(mask)` method for WHO queries
- Added `client.whois(nick)` method for WHOIS queries
- Added handlers for WHO numeric: 352 (RPL_WHOREPLY)
- Added handlers for WHOIS numerics: 311 (RPL_WHOISUSER), 319 (RPL_WHOISCHANNELS), 312 (RPL_WHOISSERVER), 317 (RPL_WHOISIDLE), 330 (RPL_WHOISACCOUNT), 301 (RPL_AWAY), 318 (RPL_ENDOFWHOIS)
- WHOIS data collected in `@pending_whois` until ENDOFWHOIS, then emitted as single `:whois` event
- `:who` event emitted for each RPL_WHOREPLY with channel, user, host, server, nick, away, realname
- Correctly handles interleaved messages during WHOIS collection
- Unit tests for WHO/WHOIS formatting, parsing, and collection (16 tests)
- Integration tests for WHO channel, WHO nick, WHO non-existent, WHOIS user, WHOIS with channels, WHOIS non-existent, WHOIS away user (7 tests)
- All tests pass (232 runs, 463 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- Public interface: `client.who(mask)`, `client.whois(nick)`
- `:who` event emitted for each matching user with: channel, user, host, server, nick, away (boolean), realname
- `:whois` event emitted after ENDOFWHOIS with `result:` (WhoisResult or nil if not found)
- WhoisResult attributes: nick, user, host, realname, channels (Array), server, idle, signon (Time), account, away

### Session 2025-11-28 (15)

**Feature**: 15-client-api
**Status**: Completed

**What was done**:
- Added `connected?` method that returns true when state is :connected
- Added `server` getter as attr_reader
- Added parameter aliases in Client#initialize:
  - `server:` (alias for `host:`)
  - `nickname:` (alias for `nick:`)
  - `username:` (alias for `user:`)
- Default handling: username and realname default to nickname if not provided
- Connection errors bubble up naturally from Socket (Errno::ECONNREFUSED, etc.)
- Unit tests for new Client API features (17 new tests)
- Integration tests for full client workflow (6 tests)
- All tests pass (254 runs, 559 assertions, 3 skips), linter clean, QA passed

**Notes for next session**:
- All planned features complete!
- Public API supports both naming conventions:
  - Original: `host:`, `nick:`, `user:`
  - New: `server:`, `nickname:`, `username:`
- `client.connected?` returns boolean state
- `client.server` returns configured server hostname

---

### Session 2025-11-29 (16)

**Feature**: 16-ssl-test-infrastructure
**Status**: Completed

**What was done**:
- Generated self-signed SSL certificates (cert.pem, key.pem) in `test/fixtures/ssl/`
- Updated `test/fixtures/inspircd.conf` to enable SSL on port 6697 using GnuTLS module
- Updated `bin/start-irc-server` to mount SSL certificates into the Docker container
- Replaced skip statements in SSL tests with actual test implementations:
  - `test_connect_with_ssl` - verifies SSL connection with VERIFY_NONE
  - `test_ssl_read_write` - verifies read/write operations over SSL
  - `test_ssl_verify_peer_fails_self_signed` - verifies VERIFY_PEER fails with self-signed cert
- Added `require_ssl_server_available` helper method
- All tests pass (255 runs, 563 assertions, 1 skip for unrelated topic test)

**Notes for next session**:
- SSL tests now run automatically (no more skips)
- Uses GnuTLS module (not OpenSSL) as that's what the inspircd Docker image provides
- To run tests with SSL, restart server with `bin/stop-irc-server && bin/start-irc-server`

### Session 2025-11-29 (17)

**Feature**: 17-github-actions-ci
**Status**: Completed

**What was done**:
- Updated `.github/workflows/main.yml`:
  - Changed trigger from `master` to `main`
  - Added separate `lint` job running `bundle exec standardrb` (Ruby 3.4)
  - Added `test` job with matrix for Ruby 3.2 and 3.4
  - Added IRC server (Docker container) for integration tests
  - Runs full test suite with `bundle exec rake test`
- Updated `Rakefile`:
  - Added `test_unit` rake task for unit tests only
  - Added `test_integration` rake task for integration tests
- Added `.gitmodules` to fix broken submodule reference for `docs/agents/rfc/modern-irc`
- CI run 19780791916 passed (Lint ✓, Ruby 3.2 ✓, Ruby 3.4 ✓)

**Notes for next session**:
- CI runs full test suite including integration tests (IRC server started via Docker)
- Use `bundle exec rake test_unit` for fast unit tests locally
- Use `bundle exec rake test_integration` for integration tests (requires IRC server)

### Session 2025-11-28 (18)

**Feature**: 18-brakeman-security-scanning
**Status**: Completed

**What was done**:
- Added brakeman gem to Gemfile
- Created `bin/brakeman` wrapper script (uses --force since this is a gem, not Rails)
- Added security job to `.github/workflows/main.yml` running brakeman
- Updated QA agent instructions to include brakeman in validation commands
- Brakeman passes with no warnings

**Notes for next session**:
- Run `bin/brakeman` to check for security issues
- CI now has lint, security, and test jobs
- QA agent now checks for security issues as part of review

---

## Suggested Next Feature

All 16 planned features are complete. The library now provides:
- IRC message parsing and serialization
- TCP/SSL connection management
- Registration (NICK, USER, PASS)
- PING/PONG handling
- Event system with handlers
- PRIVMSG/NOTICE
- JOIN/PART with channel tracking
- QUIT with disconnect events
- NICK changes with tracking
- TOPIC get/set
- KICK
- NAMES with user prefix parsing
- MODE for channels and users
- WHO/WHOIS queries
- Client API with convenience methods

### Session 2025-11-29 (19)

**Feature**: 01-tcpsocket-refactor
**Status**: Completed

**What was done**:
- Refactored `lib/yaic/socket.rb` to use `TCPSocket.new` with `connect_timeout:` parameter
- Removed `resolve_address` method (no longer needed - TCPSocket handles DNS resolution)
- Removed nonblocking connect logic (`connect_nonblock`, `IO.select`, `IO::WaitWritable`)
- Preserved keepalive via `setsockopt`
- Added `test_dns_resolution_failure` integration test (verifies SocketError for bad hostnames)
- Added `test_keepalive_option_set` integration test (verifies SO_KEEPALIVE enabled)
- All tests pass (258 runs, 566 assertions, 0 failures)

**Notes for next session**:
- Socket.connect is now much simpler - single TCPSocket.new call
- IPv4 preference logic removed (TCPSocket uses system resolver order)
- Next feature: 02-simplified-client-api.md (depends on this feature)

---

## New Feature Queue

| Feature | Status | Description |
|---------|--------|-------------|
| 01-tcpsocket-refactor.md | ✅ complete | Replace low-level Socket with TCPSocket |
| 02-simplified-client-api.md | ✅ complete | Blocking API, background read loop |

---

### Session 2025-11-29 (20)

**Feature**: 02-simplified-client-api
**Status**: Completed

**What was done**:
- Refactored `lib/yaic/client.rb` with blocking API:
  - `connect` blocks until registered (001 RPL_WELCOME received)
  - `join(channel)` blocks until channel appears in @channels
  - `part(channel)` blocks until channel removed from @channels
  - `nick(new_nick)` blocks until nick change confirmed
  - `quit` cleans up, stops read thread, disconnects
- Added background read thread in `start_read_loop` that processes incoming messages
- Added thread safety: `@handlers_mutex` for on/off, `@channels_mutex` for channel access, `@state_mutex` for state
- Added `Yaic::TimeoutError` for timeout handling
- Removed `on_socket_connected` method (no longer needed)
- Simplified all integration tests to use new blocking API:
  - Removed all `on_socket_connected` calls
  - Removed all `wait_for_connection`, `wait_for_join`, `wait_for_part`, `drain_messages` helpers
  - Tests now simply call `client.connect`, `client.join`, etc. and they block until complete
- Fixed QA issues:
  - Fixed `event.raw` to `event.message` in mode tests
  - Fixed `event.code` to `event.numeric` in kick tests
  - Fixed race conditions by using event handlers instead of direct socket reads for oper/mode waiting
- Created comprehensive README.md with Quick Start, Events, Commands, Threading, Channel State sections
- All unit tests pass (176 runs, 351 assertions)
- Linter passes

**Notes for next session**:
- Client API is now dramatically simplified:
  ```ruby
  client = Yaic::Client.new(server: "irc.example.com", port: 6667, nickname: "mynick")
  client.on(:message) { |event| puts event.text }
  client.connect
  client.join("#channel")
  client.privmsg("#channel", "Hello!")
  client.quit
  ```
- Background thread handles all message reading and event dispatch
- All public methods are thread-safe
- README.md provides complete documentation

### Session 2025-11-29 (21)

**Feature**: 19-fix-qa
**Status**: Completed

**What was done**:
- Added public `raw(command)` method to Client class for sending arbitrary IRC commands
- Updated all integration tests to use `client.raw()` instead of `instance_variable_get(:@socket).write()`
- Updated files: mode_test.rb, kick_test.rb, names_test.rb, nick_test.rb, join_part_test.rb, who_whois_test.rb
- Updated helper methods `become_oper` and `wait_for_mode` to use client.raw
- All tests pass (267 runs, 575 assertions, 0 failures)

**Notes for next session**:
- `client.raw(command)` is now the public way to send arbitrary IRC commands
- Integration tests no longer access internal socket via instance_variable_get
- The one remaining instance_variable_get in socket_test.rb is appropriate (testing Socket class internals)

---

### Session 2025-11-29 (22)

**Feature**: 20-test-optimization (Planning)
**Status**: Completed

**What was done**:
- Profiled test suite using `rake test TESTOPTS="-v"`:
  - Total test time: 173 seconds
  - 267 tests, 575 assertions
  - 79 tests take >= 1 second (172.51s cumulative)
- Analyzed slow tests and identified root causes:
  - Fixed `sleep 0.5` statements waiting for IRC responses
  - `read_multiple(socket, N)` always waits full timeout
  - Sequential test execution despite independent tests
- Created optimization plan at `docs/agents/ralph/plans/test-optimization-plan.md`
- Created follow-up implementation features:
  - `21-test-parallelization.md` - Enable parallel test execution
  - `22-wait-until-pattern.md` - Replace sleep/read_multiple with wait_until
  - `23-ping-test-optimization.md` - Optimize ping test with faster server config

**Notes for next session**:
- Plan approved by user with feedback to use `wait_until` pattern
- Next feature: 21-test-parallelization.md

---

## Test Optimization Feature Queue

| Feature | Status | Description |
|---------|--------|-------------|
| 20-test-optimization.md | ✅ complete | Planning and profiling |
| 21-test-parallelization.md | ✅ complete | Enable parallel test execution |
| 22-wait-until-pattern.md | ✅ complete | Replace sleep/read_multiple with wait_until |
| 23-ping-test-optimization.md | ✅ complete | Optimize ping test |

---

### Session 2025-11-29 (23)

**Feature**: 21-test-parallelization
**Status**: Completed

**What was done**:
- Added `UniqueTestIdentifiers` module to `test/test_helper.rb` with `unique_nick` and `unique_channel` helper methods
- Helper methods generate thread-safe identifiers using `Process.pid`, `Thread.current.object_id`, and `rand`
- Added `include UniqueTestIdentifiers` and `parallelize_me!` to all 14 integration test files
- Updated all inline nick/channel generation to use the new helper methods
- Fixed variable shadowing issues in `join_part_test.rb` and `topic_test.rb`
- Test suite time reduced from ~173 seconds to ~12-17 seconds (10x speedup)
- All 267 tests pass, 575 assertions, 0 failures, 1 pre-existing skip

**Notes for next session**:
- Parallelization achieved better than expected 3-4x target (actual: 10x speedup)
- Next feature: `22-wait-until-pattern.md` - Replace sleep/read_multiple with wait_until

---

### Session 2025-11-29 (24)

**Feature**: 22-wait-until-pattern
**Status**: Completed

**What was done**:
- Added `wait_until(timeout: 2)` helper to `test/test_helper.rb` in UniqueTestIdentifiers module
- Replaced all `sleep 0.x` statements in integration tests with `wait_until { condition }`
- Replaced `read_multiple`, `read_until_pong`, `read_until_welcome` with inline `wait_until` blocks
- Removed all old helper functions from ping_pong_test.rb, registration_test.rb, socket_test.rb
- Removed unnecessary `require "timeout"` statements
- Refactored `become_oper` and `wait_for_mode` helpers to use `wait_until`
- Updated unit tests in client_test.rb to use deadline-based waiting
- Test suite time reduced from ~13s to ~10s (additional 30% improvement)
- All 267 tests pass, 575 assertions, 0 failures, 1 pre-existing skip

**Notes for next session**:
- `wait_until` helper returns condition result or nil on timeout
- Default timeout is 2 seconds, can be overridden with `wait_until(timeout: 5)`
- Next feature: `23-ping-test-optimization.md` - Optimize ping test with faster server config

---

### Session 2025-11-29 (25)

**Feature**: 23-ping-test-optimization
**Status**: Completed

**What was done**:
- Updated `test/fixtures/inspircd.conf`: Changed `pingfreq="5"` to `pingfreq="3"`
- Updated `test/integration/ping_pong_test.rb`: Reduced `wait_until(timeout: 10)` to `wait_until(timeout: 5)`
- The `sleep 6` mentioned in the spec was already replaced with `wait_until` in session 24 (feature 22)
- Ping test now completes in ~4 seconds instead of ~7 seconds
- All 267 tests pass, 575 assertions, 0 failures, 1 pre-existing skip

**Notes for next session**:
- All test optimization features (20-23) are complete
- Test suite now runs in ~10-12 seconds (down from ~173 seconds originally)
- Server must be restarted after config changes: `bin/stop-irc-server && bin/start-irc-server`

---

### Session 2025-11-29 (26)

**Feature**: 24-blocking-who-whois
**Status**: Completed

**What was done**:
- Created `Yaic::WhoResult` class with attributes: channel, user, host, server, nick, away, realname
- Updated `who(mask, timeout:)` to block until END OF WHO (315) and return Array of WhoResult
- Updated `whois(nick, timeout:)` to block until END OF WHOIS (318) and return WhoisResult or nil
- Added `@pending_who_results`, `@pending_who_complete`, `@pending_whois_complete` tracking hashes
- Added `handle_rpl_endofwho` handler for 315 numeric
- Added `who_reply_matches_mask?` helper for correctly matching WHO replies to pending requests (channel-based vs nick-based)
- Updated unit tests (23 tests in who_whois_test.rb)
- Updated integration tests (9 tests)
- All 279 tests pass, 629 assertions, 0 failures, 0 errors, 0 skips

**Notes for next session**:
- `client.who("#channel")` now returns Array of WhoResult objects directly
- `client.whois("nick")` now returns WhoisResult or nil directly
- Events (`:who`, `:whois`) still fire for backward compatibility
- `Yaic::TimeoutError` raised on timeout
- Next feature: 25-verbose-mode.md (depends on 24-blocking-who-whois)

---

## Suggested Next Feature

Next feature to implement: `25-verbose-mode.md`
