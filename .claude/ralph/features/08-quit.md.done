# QUIT Command

## Description

Implement the QUIT command for gracefully disconnecting from the server, and handle QUIT messages from other users.

## Behavior

### Sending QUIT

```ruby
client.quit
client.quit("Gone for lunch")
```

Format: `QUIT [:<reason>]`

After sending QUIT:
1. Server sends ERROR message
2. Server closes connection
3. Client should close socket and clean up

### Server Response to QUIT

Server sends: `ERROR :Closing Link: nick[host] (Quit: reason)`

Then closes the connection.

### Other Users Quitting

When another user quits: `:nick!user@host QUIT :reason`

Server prepends "Quit: " to reason when distributing.

Netsplits appear as: `:nick!user@host QUIT :server1 server2`

### Events

Emit `:quit` event with:
- `user` - Source of the quit
- `reason` - Quit message

Emit `:disconnect` event when own connection closes.

## Models

No new models.

## Tests

### Integration Tests

**Quit without reason**
- Given: Connected client
- When: `client.quit`
- Then: Server receives "QUIT", connection closes

**Quit with reason**
- Given: Connected client
- When: `client.quit("Bye!")`
- Then: Server receives "QUIT :Bye!", connection closes

**Receive other user quit**
- Given: Client in #test with :quit handler, other user in #test
- When: Other user quits
- Then: Handler called with user=other, reason

**Detect netsplit quit**
- Given: Client with :quit handler
- When: Receive QUIT with reason "*.net *.split"
- Then: Handler receives netsplit-style reason

### Unit Tests

**Format QUIT**
- Given: No reason
- When: Build QUIT
- Then: Output = "QUIT\r\n"

**Format QUIT with reason**
- Given: reason = "Going away"
- When: Build QUIT
- Then: Output = "QUIT :Going away\r\n"

**Parse QUIT event**
- Given: `:nick!u@h QUIT :Quit: Leaving`
- When: Parse
- Then: event.user.nick = "nick", event.reason = "Quit: Leaving"

**Parse netsplit QUIT**
- Given: `:nick!u@h QUIT :hub.net leaf.net`
- When: Parse
- Then: event.reason = "hub.net leaf.net"

### State Tests

**State after quit**
- Given: Connected client
- When: Quit
- Then: State = :disconnected, channels cleared

**Cleanup after quit**
- Given: Client in multiple channels
- When: Quit
- Then: All channel tracking cleared

## Implementation Notes

- QUIT is the graceful way to disconnect
- Wait briefly for ERROR response before closing socket
- Remove quitting users from all tracked channels
- Consider implementing `client.disconnect` as alias

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
- Requires `05-event-system.md`
