# PING/PONG Keepalive

## Description

Implement PING/PONG handling to maintain connection with the server. This is critical - servers will disconnect clients that don't respond to PING.

## Behavior

### Responding to PING

When server sends `PING <token>`:
1. Immediately respond with `PONG <token>`
2. Token must be identical to what server sent
3. Can occur at any time, including during registration

### Server PING Format

```
PING <token>
PING :<token>
```

The token may be with or without the trailing `:` prefix.

### Client PONG Response

```
PONG <token>
PONG :<token>
```

Mirror the token exactly. Do NOT include a server parameter.

### Connection Timeout Detection

If no data received from server for extended period (e.g., 180+ seconds):
- Connection may be dead
- Client should consider reconnecting

### Latency Measurement (Optional)

- Client may send `PING <token>` to server
- Server responds with `PONG <token>`
- Measure round-trip time

## Models

No new models required. Handled in message dispatch.

## Tests

### Integration Tests

**Respond to PING during registration**
- Given: Connected, registration in progress
- When: Server sends PING
- Then: Client responds with PONG, registration continues

**Respond to PING when connected**
- Given: Fully connected
- When: Server sends "PING :irc.example.com"
- Then: Client sends "PONG :irc.example.com"

**Handle PING without colon**
- Given: Fully connected
- When: Server sends "PING token123"
- Then: Client sends "PONG token123"

**Maintain connection over time**
- Given: Connected to inspircd
- When: Wait for server to send PING (typically 2-5 minutes)
- Then: Client responds, connection stays alive

### Unit Tests

**Parse PING message**
- Given: "PING :test.server.com\r\n"
- When: Parse message
- Then: command = "PING", params = ["test.server.com"]

**Build PONG response**
- Given: PING with token "abc123"
- When: Build PONG
- Then: Output = "PONG abc123\r\n"

**Build PONG with spaces in token**
- Given: PING with token "some server"
- When: Build PONG
- Then: Output = "PONG :some server\r\n"

### Timeout Tests

**Detect no data timeout**
- Given: Connected, no data received for 180 seconds
- When: Check connection health
- Then: Report connection as potentially dead

## Implementation Notes

- PING handling should be automatic, not requiring user code
- Process PING before other message handling to ensure quick response
- Log PING/PONG for debugging but don't emit as regular events
- Consider emitting a `:ping` event for latency tracking

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
- Requires `03-registration.md` (PING can occur during registration)
