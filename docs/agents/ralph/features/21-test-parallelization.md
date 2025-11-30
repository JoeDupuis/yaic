# Test Parallelization

## Description

Enable minitest's built-in parallel test execution to run tests concurrently, reducing total test time by utilizing multiple CPU cores.

## Behavior

### Enable Parallel Execution

Add `parallelize_me!` to test classes or enable globally in test_helper.rb.

### Fix Unique Identifiers for Thread Safety

Tests currently use `Process.pid` for unique nicks/channels, but with thread-based parallelism all threads share the same PID. Update identifier generation to include thread ID:

```ruby
# Before
@test_nick = "t#{Process.pid}#{Time.now.to_i % 10000}"

# After
@test_nick = "t#{Process.pid}_#{Thread.current.object_id % 10000}_#{rand(10000)}"
```

### Verify Test Isolation

Ensure tests don't share state:
- Each test creates its own IRC client connections
- Each test uses unique channel names
- No global variables or class variables modified during tests

## Tests

Run the full test suite and verify:
- All 267 tests pass
- All 575 assertions pass
- No new skips introduced
- Test time is reduced (target: 3-4x speedup)

## Implementation Notes

- Use `bundle exec rake test` to run tests
- Use `bundle exec standardrb -A` for linting
- The IRC server can handle multiple concurrent connections

Minitest parallel options:
1. `parallelize_me!` in individual test classes
2. Global enable in test_helper.rb via `Minitest::Test.parallelize_me!`

## Dependencies

- 20-test-optimization.md (planning complete)

## Reference

See `docs/agents/ralph/plans/test-optimization-plan.md` for full analysis.
