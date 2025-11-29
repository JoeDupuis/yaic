# NICK Change

## Description

Implement changing nickname after registration and tracking nickname changes from other users.

## Behavior

### Changing Own Nick

```ruby
client.nick("newnick")
```

Format: `NICK <nickname>`

### Server Response

On success: `:oldnick!user@host NICK newnick`

Update internal state to track new nickname.

### Nick Change Errors

- 431 ERR_NONICKNAMEGIVEN - No nick provided
- 432 ERR_ERRONEUSNICKNAME - Invalid characters
- 433 ERR_NICKNAMEINUSE - Nick taken
- 436 ERR_NICKCOLLISION - Collision (rare)

### Other Users Changing Nick

When another user changes nick: `:oldnick!user@host NICK newnick`

Update user tracking in all shared channels.

### Events

Emit `:nick` event with:
- `old_nick` - Previous nickname
- `new_nick` - New nickname
- `user` - Source (optional, has old nick info)

## Models

```ruby
client.nick  # => current nickname (String)
```

## Tests

### Integration Tests

**Change own nick**
- Given: Connected as "oldnick"
- When: `client.nick("newnick")`
- Then: Receive NICK confirmation, client.nick = "newnick"

**Nick in use**
- Given: Connected, "taken" nick exists
- When: `client.nick("taken")`
- Then: Receive 433 ERR_NICKNAMEINUSE

**Invalid nick**
- Given: Connected
- When: `client.nick("#invalid")`
- Then: Receive 432 ERR_ERRONEUSNICKNAME

**Other user changes nick**
- Given: Client in #test with "bob", :nick handler
- When: Bob changes nick to "robert"
- Then: Handler called with old_nick="bob", new_nick="robert"

### Unit Tests

**Format NICK**
- Given: nickname = "newnick"
- When: Build NICK
- Then: Output = "NICK newnick\r\n"

**Parse NICK event**
- Given: `:old!u@h NICK new`
- When: Parse
- Then: event.old_nick = "old", event.new_nick = "new"

**Track own nick change**
- Given: client.nick = "old"
- When: Receive `:old!u@h NICK new` from self
- Then: client.nick = "new"

### Channel User Tracking

**Update user in channels**
- Given: Client tracks "bob" in #test
- When: Bob changes nick to "robert"
- Then: #test user list shows "robert" not "bob"

## Implementation Notes

- Store current nick in client.nick
- On NICK event, check if source matches own nick to update self
- Update all channel user lists when any nick changes
- Nick comparison should be case-insensitive per server CASEMAPPING

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
- Requires `03-registration.md`
- Requires `05-event-system.md`
