# Connection Registration

## Description

Implement the IRC connection registration sequence. After connecting, the client must send NICK and USER commands (optionally PASS) and wait for the server to acknowledge registration.

## Behavior

### Registration Sequence

1. If password provided, send: `PASS <password>`
2. Send: `NICK <nickname>`
3. Send: `USER <username> 0 * :<realname>`
4. Wait for numeric 001 (RPL_WELCOME) to confirm registration
5. Transition state to `:connected`

### PASS Command

- Format: `PASS <password>`
- Must be sent before NICK/USER
- Only last PASS is used if sent multiple times

### NICK Command

- Format: `NICK <nickname>`
- Can be sent during or after registration
- Server may reject with:
  - 431 ERR_NONICKNAMEGIVEN
  - 432 ERR_ERRONEUSNICKNAME
  - 433 ERR_NICKNAMEINUSE

### USER Command

- Format: `USER <username> 0 * :<realname>`
- The `0` and `*` are required (historical reasons)
- realname can contain spaces

### Handling Nick Collisions

If ERR_NICKNAMEINUSE (433) received during registration:
- Try alternative nick (append underscore or number)
- Emit event so user code can provide alternative

### Welcome Numerics

After successful registration, server sends:
- 001 RPL_WELCOME - Registration complete
- 002 RPL_YOURHOST - Server info
- 003 RPL_CREATED - Server creation time
- 004 RPL_MYINFO - Server name and supported modes
- 005 RPL_ISUPPORT - Server capabilities (multiple lines)

## Models

```ruby
Yaic::Registration
  - nickname: String
  - username: String
  - realname: String
  - password: String or nil
  - state: :pending, :nick_sent, :user_sent, :complete
```

## Tests

### Integration Tests - Successful Registration

**Register with nickname and user**
- Given: Connected to inspircd
- When: Send NICK and USER
- Then: Receive 001 RPL_WELCOME, state becomes :connected

**Register with password**
- Given: Connected to inspircd (configured with password)
- When: Send PASS, NICK, USER
- Then: Receive 001 RPL_WELCOME

### Integration Tests - Nick Handling

**Nick already in use**
- Given: Connected to inspircd, nick "taken" already connected
- When: Send NICK taken
- Then: Receive 433 ERR_NICKNAMEINUSE

**Invalid nickname**
- Given: Connected to inspircd
- When: Send NICK "#invalid"
- Then: Receive 432 ERR_ERRONEUSNICKNAME

**Empty nickname**
- Given: Connected to inspircd
- When: Send NICK with no parameter
- Then: Receive 431 ERR_NONICKNAMEGIVEN

### Unit Tests - Message Formatting

**Format PASS command**
- Given: password = "secret"
- When: Build PASS message
- Then: Output = "PASS secret\r\n"

**Format NICK command**
- Given: nickname = "mynick"
- When: Build NICK message
- Then: Output = "NICK mynick\r\n"

**Format USER command**
- Given: username = "myuser", realname = "My Real Name"
- When: Build USER message
- Then: Output = "USER myuser 0 * :My Real Name\r\n"

**Format USER with empty realname**
- Given: username = "myuser", realname = ""
- When: Build USER message
- Then: Output = "USER myuser 0 * :\r\n"

### State Machine Tests

**State transitions**
- Given: State = :disconnected
- When: Connect initiated
- Then: State = :connecting

- Given: State = :connecting
- When: Socket connected
- Then: State = :registering, NICK/USER sent

- Given: State = :registering
- When: 001 received
- Then: State = :connected

**State on nick collision**
- Given: State = :registering
- When: 433 received
- Then: State remains :registering, retry with alternate nick

## Implementation Notes

- Parse RPL_ISUPPORT (005) to learn server capabilities
- Store ISUPPORT values for later use (CHANTYPES, CHANMODES, etc.)
- Username may be prefixed with ~ if no ident server
- Some servers require PING response during registration

## Dependencies

- Requires `01-message-parsing.md`
- Requires `02-connection-socket.md`
