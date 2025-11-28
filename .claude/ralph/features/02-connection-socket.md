# Connection Socket

## Description

Implement the low-level TCP/SSL socket connection handling. This provides the transport layer for sending and receiving raw IRC messages.

## Behavior

### Connecting

1. Create TCP socket to server:port
2. If SSL enabled, wrap in OpenSSL::SSL::SSLSocket
3. Set socket to non-blocking mode for read operations
4. Transition state to `:connecting` then `:registering`

### Reading

- Read from socket into internal buffer
- Extract complete messages (ending in `\r\n`)
- Handle partial messages (keep in buffer until complete)
- Accept `\n` alone as line ending for compatibility

### Writing

- Queue outgoing messages
- Append `\r\n` if not present
- Write to socket
- Handle write blocking (rare but possible)

### Disconnecting

- Close socket gracefully
- Clear buffers
- Transition state to `:disconnected`

### Error Handling

- Handle connection refused
- Handle connection timeout
- Handle SSL handshake failures
- Handle socket read/write errors

## Models

```ruby
Yaic::Socket
  - socket: TCPSocket or SSLSocket
  - read_buffer: String
  - write_queue: Array[String]
  - state: Symbol
```

## Tests

### Integration Tests - Plain TCP

**Connect to server**
- Given: inspircd running on localhost:6667 (no SSL)
- When: Connect with ssl: false
- Then: Socket is connected, state is :connecting

**Read complete message**
- Given: Connected socket, server sends "PING :test\r\n"
- When: Read from socket
- Then: Returns "PING :test\r\n"

**Read partial then complete**
- Given: Connected socket
- When: Server sends "PING :" then ":test\r\n" in separate packets
- Then: First read returns nil, second read returns complete message

**Write message**
- Given: Connected socket
- When: Write "PONG :test"
- Then: Server receives "PONG :test\r\n"

**Disconnect**
- Given: Connected socket
- When: Disconnect
- Then: Socket is closed, state is :disconnected

### Integration Tests - SSL

**Connect with SSL**
- Given: inspircd running on localhost:6697 (SSL)
- When: Connect with ssl: true
- Then: Socket is connected via TLS

**SSL handshake failure**
- Given: Server with invalid/self-signed cert
- When: Connect with ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER
- Then: Raises SSLError or similar

### Unit Tests - Buffer Handling

**Buffer accumulates partial messages**
- Given: Empty buffer
- When: Receive "PING" then " :test" then "\r\n"
- Then: After third receive, extract "PING :test\r\n"

**Multiple messages in one read**
- Given: Empty buffer
- When: Receive "MSG1\r\nMSG2\r\n"
- Then: Extract returns ["MSG1\r\n", "MSG2\r\n"]

**Handle LF-only endings**
- Given: Empty buffer
- When: Receive "PING :test\n"
- Then: Extract returns "PING :test\n"

### Error Handling Tests

**Connection refused**
- Given: No server on target port
- When: Attempt connect
- Then: Raises connection error

**Connection timeout**
- Given: Server that doesn't respond
- When: Connect with timeout
- Then: Raises timeout error after specified time

**Read on closed socket**
- Given: Socket that was closed by server
- When: Attempt read
- Then: Returns nil or raises appropriate error

## Implementation Notes

- Use Ruby's `TCPSocket` and `OpenSSL::SSL::SSLSocket`
- Set `sync = true` on SSL socket for unbuffered writes
- Consider using `IO.select` for non-blocking reads
- Buffer should be a binary string (encoding: ASCII-8BIT)
- Implement reconnection logic in higher layer, not here

## Dependencies

- Requires `01-message-parsing.md` for message framing knowledge
