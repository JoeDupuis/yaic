# JOIN and PART

## Description

Implement joining and leaving IRC channels. This is essential for participating in channel conversations.

## Behavior

### JOIN Command

```ruby
client.join("#ruby")
client.join("#ruby", "channelkey")  # For key-protected channels
client.join("#a,#b,#c")             # Multiple channels
```

Format: `JOIN <channel>[,<channel>...] [<key>[,<key>...]]`

Special case: `JOIN 0` leaves all channels.

### Server Response to JOIN

On successful join, server sends:
1. `:yournick!user@host JOIN #channel` - Confirmation
2. `332 RPL_TOPIC` - Channel topic (if set)
3. `333 RPL_TOPICWHOTIME` - Who set topic and when (optional)
4. `353 RPL_NAMREPLY` - List of users in channel (may be multiple)
5. `366 RPL_ENDOFNAMES` - End of names list

### JOIN Errors

- 403 ERR_NOSUCHCHANNEL - Invalid channel name
- 405 ERR_TOOMANYCHANNELS - Client limit reached
- 471 ERR_CHANNELISFULL - Channel is full (+l mode)
- 473 ERR_INVITEONLYCHAN - Channel is invite-only (+i mode)
- 474 ERR_BANNEDFROMCHAN - Banned from channel
- 475 ERR_BADCHANNELKEY - Wrong or missing key (+k mode)

### PART Command

```ruby
client.part("#ruby")
client.part("#ruby", "Goodbye!")  # With reason
client.part("#a,#b")              # Multiple channels
```

Format: `PART <channel>[,<channel>...] [:<reason>]`

### Server Response to PART

Server sends: `:yournick!user@host PART #channel :reason`

### PART Errors

- 403 ERR_NOSUCHCHANNEL - Channel doesn't exist
- 442 ERR_NOTONCHANNEL - Not in that channel

### Tracking Other Users

When other users JOIN/PART:
- `:othernick!user@host JOIN #channel`
- `:othernick!user@host PART #channel :reason`

Emit appropriate events for these.

## Models

Track joined channels:
```ruby
client.channels  # => {"#ruby" => Yaic::Channel, ...}
```

## Tests

### Integration Tests - JOIN

**Join single channel**
- Given: Connected client
- When: `client.join("#test")`
- Then: Receive JOIN confirmation, RPL_NAMREPLY, RPL_ENDOFNAMES

**Join channel with topic**
- Given: Connected client, #test has topic
- When: `client.join("#test")`
- Then: Receive RPL_TOPIC with topic text

**Join key-protected channel**
- Given: Connected client, #secret requires key "pass123"
- When: `client.join("#secret", "pass123")`
- Then: Successfully joins

**Join key-protected with wrong key**
- Given: Connected client, #secret requires key
- When: `client.join("#secret", "wrongkey")`
- Then: Receive 475 ERR_BADCHANNELKEY

**Join multiple channels**
- Given: Connected client
- When: `client.join("#a,#b,#c")`
- Then: Joined to all three channels

**Join non-existent channel creates it**
- Given: Connected client
- When: `client.join("#newchannel")`
- Then: Channel created, client is operator

### Integration Tests - PART

**Part single channel**
- Given: Client in #test
- When: `client.part("#test")`
- Then: Receive PART confirmation, channel removed from tracking

**Part with reason**
- Given: Client in #test
- When: `client.part("#test", "Going home")`
- Then: Reason included in PART message

**Part channel not in**
- Given: Client not in #other
- When: `client.part("#other")`
- Then: Receive 442 ERR_NOTONCHANNEL

### Integration Tests - Events

**Emit :join event on self join**
- Given: Client with :join handler
- When: Join #test
- Then: Handler called with channel="#test", user=self

**Emit :join event on other join**
- Given: Client in #test with :join handler
- When: Other user joins #test
- Then: Handler called with channel="#test", user=other

**Emit :part event on self part**
- Given: Client in #test with :part handler
- When: Part #test
- Then: Handler called with channel="#test", user=self

**Emit :part event on other part**
- Given: Client in #test with :part handler
- When: Other user parts #test
- Then: Handler called with channel="#test", user=other, reason

### Unit Tests

**Format JOIN**
- Given: channel = "#test"
- When: Build JOIN
- Then: Output = "JOIN #test\r\n"

**Format JOIN with key**
- Given: channel = "#test", key = "secret"
- When: Build JOIN
- Then: Output = "JOIN #test secret\r\n"

**Format PART**
- Given: channel = "#test"
- When: Build PART
- Then: Output = "PART #test\r\n"

**Format PART with reason**
- Given: channel = "#test", reason = "Bye all"
- When: Build PART
- Then: Output = "PART #test :Bye all\r\n"

**Parse JOIN event**
- Given: `:nick!u@h JOIN #test`
- When: Parse
- Then: event.channel = "#test", event.user.nick = "nick"

**Parse PART event**
- Given: `:nick!u@h PART #test :Later`
- When: Parse
- Then: event.channel = "#test", event.user.nick = "nick", event.reason = "Later"

## Implementation Notes

- Track which channels client is in via `client.channels` hash
- Update channel user list on JOIN/PART from others
- RPL_NAMREPLY may come in multiple messages - collect until RPL_ENDOFNAMES
- Channel names start with # or & (check CHANTYPES from ISUPPORT)

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
- Requires `03-registration.md`
- Requires `05-event-system.md`
