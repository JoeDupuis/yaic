# Channel NAMES

## Description

Implement querying channel user lists. NAMES returns all users in a channel with their mode prefixes.

## Behavior

### Requesting NAMES

```ruby
client.names("#ruby")
```

Format: `NAMES <channel>`

### Server Response

- 353 RPL_NAMREPLY - User list (may be multiple)
- 366 RPL_ENDOFNAMES - End of list

RPL_NAMREPLY format: `:server 353 mynick = #channel :@op +voice regular`

User prefixes:
- `@` - Operator
- `+` - Voice
- `%` - Half-op (some servers)
- `~` - Owner (some servers)
- `&` - Admin (some servers)

### Events

Emit `:names` event with:
- `channel` - Channel name
- `users` - Array of {nick:, modes:} or similar

Or update channel.users and emit general update event.

## Models

```ruby
channel.users  # => Hash[String, Set[Symbol]]
               # e.g., {"dan" => Set[:op], "bob" => Set[:voice]}
```

## Tests

### Integration Tests

**Get names**
- Given: Client in #test with users
- When: `client.names("#test")`
- Then: Receive RPL_NAMREPLY with user list

**Names with prefixes**
- Given: #test has @op and +voice users
- When: `client.names("#test")`
- Then: Response shows prefixes

**Names at join**
- Given: Client joins #test
- When: JOIN completes
- Then: channel.users populated from NAMREPLY

**Multi-message names**
- Given: Channel with many users
- When: Request NAMES
- Then: Multiple RPL_NAMREPLY collected until RPL_ENDOFNAMES

### Unit Tests

**Parse RPL_NAMREPLY**
- Given: `:server 353 me = #test :@op +voice regular`
- When: Parse
- Then: Extract users with modes: op=>[:op], voice=>[:voice], regular=>[]

**Parse prefix @ (op)**
- Given: User string "@dan"
- When: Parse user
- Then: nick = "dan", modes = [:op]

**Parse prefix + (voice)**
- Given: User string "+bob"
- When: Parse user
- Then: nick = "bob", modes = [:voice]

**Parse multiple prefixes**
- Given: User string "@+admin"
- When: Parse user
- Then: nick = "admin", modes = [:op, :voice]

**Parse no prefix**
- Given: User string "regular"
- When: Parse user
- Then: nick = "regular", modes = []

**Collect until ENDOFNAMES**
- Given: Multiple RPL_NAMREPLY then RPL_ENDOFNAMES
- When: Process all
- Then: All users aggregated before emitting event

### State Updates

**Populate users on join**
- Given: Client joins #test
- When: NAMREPLY received
- Then: channel.users contains all listed users

**Update user modes**
- Given: Client tracking #test
- When: New NAMES requested and received
- Then: channel.users updated

## Implementation Notes

- NAMREPLY at JOIN is same as explicit NAMES command
- May receive multiple NAMREPLY messages - collect all before processing
- PREFIX in ISUPPORT defines which prefixes map to which modes
- Default: @ = op, + = voice

## Dependencies

- Requires `01-message-parsing.md`
- Requires `07-join-part.md` (NAMES comes with JOIN)
