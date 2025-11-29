# TCPSocket Refactor

## Description

Replace the low-level `::Socket` usage in `lib/yaic/socket.rb` with Ruby's higher-level `TCPSocket` class. The current implementation uses `::Socket.new` with manual address resolution and nonblocking connect patterns. `TCPSocket` provides a simpler, more readable interface while still supporting the same functionality.

## Behavior

### Current Implementation

The current socket uses:
- `::Socket.new(afamily, SOCK_STREAM)` - low-level socket creation
- `Addrinfo.getaddrinfo` - manual DNS resolution with IPv4 preference
- `connect_nonblock` with `IO.select` timeout handling
- `setsockopt` for TCP keepalive

### Target Implementation

Replace with `TCPSocket` which:
- Handles address resolution internally
- Provides cleaner connection semantics with built-in timeout support
- Maintains SSL wrapping compatibility

### Changes Required

1. **Remove `resolve_address` method** - `TCPSocket.new` handles DNS resolution
2. **Replace `::Socket.new` with `TCPSocket.new`** in the `connect` method
3. **Use `connect_timeout` parameter** - `TCPSocket.new(host, port, connect_timeout: timeout)` (Ruby 3.0+)
4. **Remove nonblocking connect logic** - no more `connect_nonblock`, `IO.select`, or `IO::WaitWritable` handling
5. **Preserve keepalive** - Use `setsockopt` on the returned TCPSocket
6. **SSL wrapping remains unchanged** - `wrap_ssl` works with any socket-like object

### Connection Flow (After)

```ruby
def connect
  tcp_socket = TCPSocket.new(@host, @port, connect_timeout: @connect_timeout)
  tcp_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)

  @socket = @ssl ? wrap_ssl(tcp_socket) : tcp_socket
  @state = :connecting
end
```

### Error Handling

- `Errno::ETIMEDOUT` - connection timeout (behavior unchanged)
- `Errno::ECONNREFUSED` - server not listening (behavior unchanged)
- `SocketError` - DNS resolution failure (new, replaces custom handling)

## Models

No database models involved. This is a refactor of the `Yaic::Socket` class.

## Tests

### Unit Tests

The existing unit tests in `test/socket_test.rb` test private buffer methods via `send()`. These do not need modification as they don't test connection logic.

### Integration Tests

Update `test/integration/socket_test.rb` to verify the refactored implementation:

**Connection to running server**
- Given: IRC server running on localhost:6667
- When: `Socket.new("localhost", 6667).connect`
- Then: Socket state is `:connecting`, socket is usable

**Connection with SSL**
- Given: IRC server running with SSL on localhost:6697
- When: `Socket.new("localhost", 6697, ssl: true).connect`
- Then: Socket state is `:connecting`, SSL handshake completed

**Connection timeout**
- Given: Non-routable IP like 10.255.255.1
- When: `Socket.new("10.255.255.1", 6667, connect_timeout: 1).connect`
- Then: Raises `Errno::ETIMEDOUT` within ~1 second

**Connection refused**
- Given: No server running on localhost:59999
- When: `Socket.new("localhost", 59999).connect`
- Then: Raises `Errno::ECONNREFUSED`

**DNS resolution failure**
- Given: Non-existent hostname
- When: `Socket.new("this.host.does.not.exist.invalid", 6667).connect`
- Then: Raises `SocketError` with DNS-related message

**Keepalive option set**
- Given: Server running
- When: Connect and inspect socket options
- Then: `SO_KEEPALIVE` option is enabled on the underlying socket

**Read/write still work after refactor**
- Given: Connected socket
- When: Write a message and read response
- Then: Nonblocking I/O behavior unchanged

## Implementation Notes

- Ruby 3.0+ only - uses `connect_timeout` parameter
- The `TCPSocket` class is in the `socket` library, already required
- `TCPSocket` is a subclass of `IPSocket` which is a subclass of `BasicSocket`, so all socket methods remain available
- IPv4 preference logic in `resolve_address` will be lost - `TCPSocket` uses system resolver order. This is acceptable for modern dual-stack systems.

## Dependencies

None - this is a standalone refactoring task.
