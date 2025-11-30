# Test Optimization Plan

## Profiling Results

**Total test time**: 173 seconds
**Total tests**: 267
**Tests >= 1 second**: 79 tests (172.51s cumulative)
**Tests < 1 second**: 188 tests (0.54s cumulative)

### Slowest Tests (> 3 seconds)

| Test | Time | Root Cause |
|------|------|------------|
| `PingPongIntegrationTest#test_client_automatically_responds_to_server_ping` | 7.01s | Intentional `sleep 6` to wait for server PING |
| `NamesIntegrationTest#test_multi_message_names` | 5.73s | Creates 5 clients, each taking ~1s to connect |
| `SocketIntegrationTest#test_ssl_read_write` | 5.01s | `read_multiple(socket, 5)` - full timeout wait |
| `RegistrationIntegrationTest#test_invalid_nickname` | 5.01s | `read_multiple(socket, 5)` - full timeout wait |
| `SocketIntegrationTest#test_write_message` | 5.00s | `read_multiple(socket, 5)` - full timeout wait |
| `RegistrationIntegrationTest#test_empty_nickname` | 5.00s | `read_multiple(socket, 5)` - full timeout wait |
| `KickIntegrationTest#test_receive_kick_others` | 4.13s | Creates 3 clients + oper setup + sleep 0.5 |
| `ModeIntegrationTest#test_give_op_to_user` | 3.12s | 2 clients + oper setup + sleep 0.5 |
| `KickIntegrationTest#test_receive_kick_self` | 3.12s | 2 clients + oper setup + sleep 0.5 |
| `KickIntegrationTest#test_kick_user` | 3.12s | 2 clients + oper setup + sleep 0.5 |
| `TopicIntegrationTest#test_receive_topic_change` | 3.06s | 2 clients + sleep 0.5 |
| `PingPongIntegrationTest#test_respond_to_server_ping_during_registration` | 3.02s | `read_multiple(socket, 3)` timeout |

### Root Causes Identified

1. **Fixed sleep statements**: Many tests use `sleep 0.5` to wait for IRC responses
2. **Full timeout waits**: `read_multiple(socket, N)` always waits N seconds even if data arrives immediately
3. **Multiple client connections**: Each `client.connect` takes ~1 second due to registration
4. **Sequential test execution**: Tests run one at a time despite being independent

## Proposed Optimizations

### Optimization 1: Enable Parallel Test Execution

**Description**: Use minitest's built-in parallel executor to run tests concurrently.

**Changes**:
- Add `parallelize_me!` to test classes or enable globally
- Tests already use unique nicks/channels via `Process.pid` and `Time.now.to_i`

**Expected Impact**: 3-4x speedup (utilize multiple CPU cores)

**Risk**: Low - tests already use unique identifiers, no shared state between tests

**Implementation**:
```ruby
# test/test_helper.rb
require "minitest/autorun"
class Minitest::Test
  parallelize_me!
end
```

### Optimization 2: Replace `sleep` with `wait_until` Pattern

**Description**: Replace `sleep 0.5` with `wait_until` style helpers that return as soon as condition is met.

**Changes**:
- Create `wait_until(timeout: 2) { condition }` helper in test_helper.rb
- Replace `sleep 0.5` with targeted `wait_until` calls

**Expected Impact**: Each test saves 0.3-0.4s (event typically arrives in 0.1s)

**Risk**: Low - uses existing event system, fails fast if event doesn't arrive

**Example**:
```ruby
# Before
client1.kick(@test_channel, @test_nick2)
sleep 0.5
assert kick_received

# After
client1.kick(@test_channel, @test_nick2)
wait_until { kick_received }
assert kick_received
```

### Optimization 3: Replace `read_multiple`/`read_until_*` with `wait_until` Pattern

**Description**: Rename and refactor `read_multiple`, `read_until_pong`, etc. to use consistent `wait_until` naming.

**Changes**:
- Replace `read_multiple(socket, 5)` with `wait_until(timeout: 2) { messages.any? { |m| m.command == "432" } }`
- Remove confusingly-named helpers in favor of inline `wait_until` blocks

**Expected Impact**: 4 tests save ~15 seconds total

**Risk**: Low - clearer code, faster execution

**Example**:
```ruby
# Before (always waits 5 seconds)
messages = read_multiple(socket, 5)
erroneous = messages.find { |m| m.command == "432" }

# After (returns when error found or timeout)
erroneous = nil
wait_until(timeout: 2) do
  raw = socket.read
  if raw
    msg = Yaic::Message.parse(raw)
    erroneous = msg if msg&.command == "432"
  end
  erroneous
end
```

### Optimization 4: Optimize Ping Test with Faster Server Config

**Description**: The `test_client_automatically_responds_to_server_ping` waits 6 seconds for server PING.

**Changes**:
- Reduce server's ping frequency in test config from 5s to 3s
- Use `wait_until` to detect when PING/PONG cycle completes instead of fixed sleep

**Expected Impact**: Save ~4 seconds

**Risk**: Low - just reducing wait time and using event-driven approach

## Implementation Order

1. **Parallel execution** (biggest impact, lowest risk)
2. **Replace `sleep 0.5` with event waits** (many small wins)
3. **Fix `read_multiple` pattern** (4 tests)
4. **Optimize ping test** (1 test)

## Parallelization Safety Analysis

### Already Safe (unique identifiers per test)

All integration tests generate unique identifiers:
```ruby
@test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"
@test_channel = "#test#{Process.pid}#{Time.now.to_i % 10000}"
```

When running in parallel, each test process/thread has different:
- `Process.pid` (if forked)
- `Time.now.to_i % 10000` (high probability of uniqueness)

### Potential Issue: Thread-based parallelism

If using threads (not forks), `Process.pid` will be the same for all tests. Need to add thread ID:
```ruby
@test_nick = "t#{Process.pid}_#{Thread.current.object_id % 10000}_#{Time.now.to_i % 10000}"
```

### Shared Resources

- IRC server: Can handle multiple concurrent connections
- `become_oper`: Uses single shared oper account - safe, oper can be used from multiple connections
- No file system or database shared state

## Verification Plan

1. Run `rake test` and verify all tests pass
2. Count tests: should be 267
3. Count assertions: should be 575
4. Time should be significantly reduced (target: < 60s)

## Risk Assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| Parallel execution | Low | Tests already isolated by design |
| Event-driven waits | Low | Fallback timeout prevents hangs |
| read_multiple fix | Low | Backwards compatible |
| Ping test optimization | Medium | May need server config tuning |
