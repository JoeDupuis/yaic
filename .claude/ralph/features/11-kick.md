# Channel KICK

## Description

Implement kicking users from channels and handling being kicked.

## Behavior

### Sending KICK

```ruby
client.kick("#ruby", "baduser")
client.kick("#ruby", "baduser", "No spamming")
```

Format: `KICK <channel> <nick> [:<reason>]`

Requires channel operator privileges.

### Server Response

Server confirms: `:kicker!user@host KICK #channel kicked :reason`

### Being Kicked

When client is kicked:
1. Receive KICK message
2. Remove channel from tracking
3. Emit :kick event

### Kick Errors

- 441 ERR_USERNOTINCHANNEL - Target not in channel
- 442 ERR_NOTONCHANNEL - Kicker not in channel
- 482 ERR_CHANOPRIVSNEEDED - Kicker not op

### Events

Emit `:kick` event with:
- `channel` - Channel name
- `user` - Who was kicked (nick)
- `by` - Who kicked (Source)
- `reason` - Kick reason

## Models

No new models.

## Tests

### Integration Tests

**Kick user**
- Given: Client is op in #test, "target" is in #test
- When: `client.kick("#test", "target")`
- Then: Target removed from channel

**Kick with reason**
- Given: Client is op in #test
- When: `client.kick("#test", "target", "Breaking rules")`
- Then: Reason included in KICK

**Kick without permission**
- Given: Client in #test (not op)
- When: `client.kick("#test", "target")`
- Then: Receive 482 ERR_CHANOPRIVSNEEDED

**Kick non-existent user**
- Given: Client is op in #test
- When: `client.kick("#test", "nobody")`
- Then: Receive 441 ERR_USERNOTINCHANNEL

**Receive kick (others)**
- Given: Client in #test with :kick handler
- When: Op kicks "baduser"
- Then: Handler called with channel, user="baduser", by=op

**Receive kick (self)**
- Given: Client in #test
- When: Op kicks client
- Then: :kick event emitted, #test removed from channels

### Unit Tests

**Format KICK**
- Given: channel = "#test", nick = "target"
- When: Build KICK
- Then: Output = "KICK #test target\r\n"

**Format KICK with reason**
- Given: channel = "#test", nick = "target", reason = "Bye"
- When: Build KICK
- Then: Output = "KICK #test target :Bye\r\n"

**Parse KICK event**
- Given: `:op!u@h KICK #test target :reason`
- When: Parse
- Then: event.channel = "#test", event.user = "target", event.by.nick = "op", event.reason = "reason"

### State Updates

**Remove kicked user from channel**
- Given: Client tracking "target" in #test
- When: KICK for "target"
- Then: "target" removed from #test user list

**Remove channel when self kicked**
- Given: Client in #test
- When: Kicked from #test
- Then: #test removed from client.channels

## Implementation Notes

- Kick requires op status (@) in channel
- Server may have kick reason length limits
- After being kicked, must rejoin if allowed

## Dependencies

- Requires `01-message-parsing.md`
- Requires `05-event-system.md`
- Requires `07-join-part.md` (channel tracking)
