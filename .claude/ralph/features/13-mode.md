# MODE Command

## Description

Implement user and channel mode queries and changes. This covers both viewing and setting modes.

## Behavior

### User Modes

Query own modes:
```ruby
client.mode(client.nick)  # Get current modes
```

Set own modes:
```ruby
client.mode(client.nick, "+i")  # Set invisible
client.mode(client.nick, "-i")  # Unset invisible
```

Common user modes:
- `+i` - Invisible (hide from WHO unless sharing channel)
- `+w` - Receive wallops
- `+o` - Operator (set via OPER, not MODE)

### Channel Modes

Query channel modes:
```ruby
client.mode("#ruby")  # Get channel modes
```

Set channel modes (requires op):
```ruby
client.mode("#ruby", "+m")           # Set moderated
client.mode("#ruby", "+o", "nick")   # Give op to nick
client.mode("#ruby", "+k", "secret") # Set channel key
client.mode("#ruby", "-k")           # Remove key
```

Common channel modes:
- `+o nick` - Channel operator
- `+v nick` - Voice
- `+m` - Moderated (only +v/+o can speak)
- `+i` - Invite only
- `+k key` - Require key to join
- `+l limit` - User limit
- `+b mask` - Ban mask
- `+t` - Only ops can change topic

### Server Response

Mode query: `324 RPL_CHANNELMODEIS :server 324 mynick #chan +nt`

Mode change: `:nick!u@h MODE #chan +o target`

### Mode Errors

- 472 ERR_UNKNOWNMODE - Unknown mode character
- 482 ERR_CHANOPRIVSNEEDED - Need op to change channel mode
- 501 ERR_UMODEUNKNOWNFLAG - Unknown user mode

### Events

Emit `:mode` event with:
- `target` - Channel or nick
- `modes` - Mode string (e.g., "+o-v")
- `params` - Mode parameters array

## Models

```ruby
channel.modes  # => Hash[Symbol, Object]
               # e.g., {moderated: true, key: "secret", limit: 50}
```

## Tests

### Integration Tests - User Modes

**Get own modes**
- Given: Connected client
- When: `client.mode(client.nick)`
- Then: Receive 221 RPL_UMODEIS

**Set invisible**
- Given: Connected client
- When: `client.mode(client.nick, "+i")`
- Then: Mode confirmed, hidden from WHO

**Cannot set other user's modes**
- Given: Connected client
- When: `client.mode("other", "+i")`
- Then: Receive 502 ERR_USERSDONTMATCH

### Integration Tests - Channel Modes

**Get channel modes**
- Given: Client in #test
- When: `client.mode("#test")`
- Then: Receive 324 RPL_CHANNELMODEIS

**Set channel mode as op**
- Given: Client is op in #test
- When: `client.mode("#test", "+m")`
- Then: Mode confirmed

**Give op to user**
- Given: Client is op in #test, "target" in channel
- When: `client.mode("#test", "+o", "target")`
- Then: Target becomes op

**Set key**
- Given: Client is op in #test
- When: `client.mode("#test", "+k", "secret")`
- Then: Channel now requires key

**Mode without permission**
- Given: Client in #test (not op)
- When: `client.mode("#test", "+m")`
- Then: Receive 482 ERR_CHANOPRIVSNEEDED

### Unit Tests

**Format MODE query**
- Given: target = "#test"
- When: Build MODE (no modes)
- Then: Output = "MODE #test\r\n"

**Format MODE set**
- Given: target = "#test", modes = "+m"
- When: Build MODE
- Then: Output = "MODE #test +m\r\n"

**Format MODE with params**
- Given: target = "#test", modes = "+o", params = ["nick"]
- When: Build MODE
- Then: Output = "MODE #test +o nick\r\n"

**Parse MODE event**
- Given: `:op!u@h MODE #test +o target`
- When: Parse
- Then: target = "#test", modes = "+o", params = ["target"]

**Parse multi-mode**
- Given: `:op!u@h MODE #test +ov target1 target2`
- When: Parse
- Then: modes = "+ov", params = ["target1", "target2"]

### State Updates

**Track channel modes**
- Given: Client in #test
- When: MODE +m received
- Then: channel.modes[:moderated] = true

**Track user op status**
- Given: Client tracking "nick" in #test
- When: MODE +o nick received
- Then: "nick" has :op in user modes

## Implementation Notes

- Parse CHANMODES from ISUPPORT for parameter requirements
- Mode types: A (list), B (always param), C (param on set), D (no param)
- Multiple modes can be set at once: +ov nick1 nick2
- Track modes received both at join and via MODE messages

## Dependencies

- Requires `01-message-parsing.md`
- Requires `05-event-system.md`
- Requires `07-join-part.md` (channel tracking)
