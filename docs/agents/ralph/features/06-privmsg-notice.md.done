# PRIVMSG and NOTICE

## Description

Implement sending and receiving private messages and notices. This is the core messaging functionality of IRC.

## Behavior

### Sending PRIVMSG

```ruby
client.privmsg("#channel", "Hello everyone!")
client.privmsg("nickname", "Hello you!")
```

Format: `PRIVMSG <target> :<text>`

Target can be:
- Channel name (e.g., `#ruby`)
- Nickname (e.g., `dan`)

### Sending NOTICE

```ruby
client.notice("#channel", "Announcement!")
client.notice("nickname", "FYI...")
```

Format: `NOTICE <target> :<text>`

Same targets as PRIVMSG. Key difference: bots should use NOTICE to avoid loops.

### Receiving PRIVMSG

Incoming format: `:nick!user@host PRIVMSG <target> :<text>`

Parse and emit `:message` event with:
- `source` - Yaic::Source of sender
- `target` - Channel or own nick
- `text` - Message content

### Receiving NOTICE

Incoming format: `:nick!user@host NOTICE <target> :<text>`

Parse and emit `:notice` event with same fields as :message.

### Error Responses

- 401 ERR_NOSUCHNICK - Target user doesn't exist
- 404 ERR_CANNOTSENDTOCHAN - Cannot send to channel (banned, moderated, not joined)
- 407 ERR_TOOMANYTARGETS - Too many targets

### Message Length

- Messages over 512 bytes (total) will be truncated by server
- Client should warn or split long messages
- Usable text length ≈ 400-450 chars depending on nick/channel length

## Models

No new models. Uses existing Message and Event.

## Tests

### Integration Tests - Sending

**Send PRIVMSG to channel**
- Given: Client joined to #test
- When: `client.privmsg("#test", "Hello")`
- Then: Server receives "PRIVMSG #test :Hello"

**Send PRIVMSG to user**
- Given: Connected client
- When: `client.privmsg("othernick", "Hello")`
- Then: Server receives "PRIVMSG othernick :Hello"

**Send NOTICE to channel**
- Given: Client joined to #test
- When: `client.notice("#test", "Announcement")`
- Then: Server receives "NOTICE #test :Announcement"

**Send message with special characters**
- Given: Connected client
- When: `client.privmsg("#test", "Hello :) world")`
- Then: Server receives "PRIVMSG #test :Hello :) world" (colon preserved)

### Integration Tests - Receiving

**Receive PRIVMSG from user**
- Given: Client with :message handler
- When: Other user sends PRIVMSG to client's nick
- Then: Handler receives event with source, target=own_nick, text

**Receive PRIVMSG in channel**
- Given: Client joined #test with :message handler
- When: Other user sends PRIVMSG to #test
- Then: Handler receives event with source, target="#test", text

**Receive NOTICE**
- Given: Client with :notice handler
- When: Server sends NOTICE
- Then: Handler receives event with source, target, text

**Distinguish channel from private message**
- Given: :message handler that tracks target
- When: Receive PRIVMSG to "#chan" vs PRIVMSG to "mynick"
- Then: target reflects correct destination

### Unit Tests - Message Formatting

**Format PRIVMSG**
- Given: target = "#test", text = "Hello"
- When: Build PRIVMSG
- Then: Output = "PRIVMSG #test :Hello\r\n"

**Format PRIVMSG with colon in text**
- Given: target = "#test", text = ":smile:"
- When: Build PRIVMSG
- Then: Output = "PRIVMSG #test ::smile:\r\n"

**Format NOTICE**
- Given: target = "nick", text = "Info"
- When: Build NOTICE
- Then: Output = "NOTICE nick :Info\r\n"

### Unit Tests - Event Parsing

**Parse PRIVMSG event**
- Given: `:dan!d@host PRIVMSG #ruby :Hello everyone`
- When: Parse and create event
- Then: event.type = :message, source.nick = "dan", target = "#ruby", text = "Hello everyone"

**Parse NOTICE event**
- Given: `:server NOTICE * :Looking up hostname`
- When: Parse and create event
- Then: event.type = :notice, source = server, target = "*", text = "Looking up hostname"

### Error Handling Tests

**Send to non-existent nick**
- Given: Connected client
- When: `client.privmsg("nonexistent", "Hello")`
- Then: Receive 401 ERR_NOSUCHNICK, :error event emitted

**Send to channel not joined**
- Given: Connected client, not in #secret
- When: `client.privmsg("#secret", "Hello")`
- Then: Receive 404 ERR_CANNOTSENDTOCHAN

## Implementation Notes

- PRIVMSG text always needs trailing colon prefix (may contain spaces)
- Consider convenience method: `client.msg(target, text)` as alias for privmsg
- Bot authors should use notice() for automatic responses
- Track own nick to detect private vs channel messages

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
- Requires `03-registration.md` (must be registered to send)
- Requires `05-event-system.md`
