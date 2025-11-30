# Wait Until Pattern

## Description

Replace `sleep 0.5`, `read_multiple`, `read_until_pong`, and similar patterns with a consistent `wait_until` helper that returns as soon as a condition is met.

## Behavior

### Create wait_until Helper

Add a `wait_until` helper to test_helper.rb:

```ruby
def wait_until(timeout: 2)
  deadline = Time.now + timeout
  until Time.now > deadline
    result = yield
    return result if result
    sleep 0.01
  end
  nil
end
```

### Replace sleep Statements

Replace `sleep 0.5` with `wait_until { condition }`:

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

### Replace read_multiple Pattern

Replace `read_multiple(socket, 5)` with inline `wait_until`:

```ruby
# Before
messages = read_multiple(socket, 5)
erroneous = messages.find { |m| m.command == "432" }

# After
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

### Remove Old Helpers

Remove these helpers from test files:
- `read_multiple`
- `read_until_pong`
- `read_until_welcome`
- `read_with_timeout`

## Tests

Run the full test suite and verify:
- All tests pass
- No assertions removed or weakened
- Test time is reduced

## Implementation Notes

- Use `bundle exec rake test` to run tests
- Use `bundle exec standardrb -A` for linting
- Focus on integration tests first (they have the most sleeps)

## Dependencies

- 20-test-optimization.md (planning complete)
- 21-test-parallelization.md (optional, can be done in parallel)

## Reference

See `docs/agents/ralph/plans/test-optimization-plan.md` for full analysis.
