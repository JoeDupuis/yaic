# Ping Test Optimization

## Description

Optimize the `test_client_automatically_responds_to_server_ping` test which currently takes 7 seconds due to a `sleep 6` waiting for the server's PING.

## Behavior

### Reduce Server Ping Frequency

Update the InspIRCd test config (`test/fixtures/inspircd.conf`) to reduce ping frequency from 5 seconds to 3 seconds.

### Use wait_until Instead of Fixed Sleep

Replace the `sleep 6` with a `wait_until` that detects when a PING/PONG cycle has occurred:

```ruby
# Before
sleep 6
assert client.last_received_at > initial_last_received

# After
wait_until(timeout: 5) { client.last_received_at > initial_last_received }
assert client.last_received_at > initial_last_received
```

## Tests

Run the ping pong integration tests and verify:
- All tests pass
- `test_client_automatically_responds_to_server_ping` completes in ~3-4 seconds instead of 7

## Implementation Notes

- Use `bundle exec m test/integration/ping_pong_test.rb` to run just ping tests
- Use `bundle exec standardrb -A` for linting
- After changing server config, restart the IRC server: `bin/stop-irc-server && bin/start-irc-server`

## Dependencies

- 20-test-optimization.md (planning complete)
- 22-wait-until-pattern.md (wait_until helper must exist)

## Reference

See `docs/agents/ralph/plans/test-optimization-plan.md` for full analysis.
