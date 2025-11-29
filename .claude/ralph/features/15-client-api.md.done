# Client API

## Description

Implement the main `Yaic::Client` class that ties everything together and provides the public interface.

## Behavior

### Initialization

```ruby
client = Yaic::Client.new(
  server: "irc.libera.chat",
  port: 6697,
  ssl: true,
  nickname: "mynick",
  username: "myuser",      # optional, defaults to nickname
  realname: "My Real Name" # optional, defaults to nickname
)
```

### Connection

```ruby
client.connect  # Blocking - connects and starts event loop
```

### Event Registration

```ruby
client.on(:message) { |event| puts event.text }
client.on(:join) { |event| puts "#{event.user} joined #{event.channel}" }
```

### Commands

```ruby
client.join("#ruby")
client.join("#ruby", "key")
client.part("#ruby")
client.part("#ruby", "reason")
client.privmsg("#ruby", "Hello!")
client.privmsg("nick", "Private message")
client.notice("#ruby", "Notice")
client.nick("newnick")
client.topic("#ruby")
client.topic("#ruby", "New topic")
client.quit
client.quit("Goodbye")
client.kick("#ruby", "nick")
client.kick("#ruby", "nick", "reason")
client.mode("#ruby")
client.mode("#ruby", "+m")
client.who("#ruby")
client.whois("nick")
client.names("#ruby")
```

### State Access

```ruby
client.nick        # Current nickname
client.connected?  # Boolean
client.channels    # Hash of joined channels
client.server      # Server hostname
```

### Error Handling

- Connection errors raise appropriate exceptions
- Server errors emit `:error` events

## Models

```ruby
Yaic::Client
  - config: Hash
  - socket: Yaic::Socket
  - handlers: Hash[Symbol, Array[Block]]
  - channels: Hash[String, Yaic::Channel]
  - nick: String
  - state: Symbol
```

## Tests

### Integration Tests - Full Flow

**Connect and receive welcome**
- Given: New client configured for inspircd
- When: `client.connect`
- Then: Connected, :connect event fired

**Join channel and send message**
- Given: Connected client
- When: Join #test, send PRIVMSG
- Then: Message received by other client in channel

**Receive and handle message**
- Given: Connected client in #test with :message handler
- When: Other client sends message
- Then: Handler called with correct event

**Full session lifecycle**
- Given: New client
- When: Connect, join, chat, part, quit
- Then: All operations succeed, clean disconnect

### Unit Tests - Initialization

**Default values**
- Given: Only server, port, ssl, nickname provided
- When: Create client
- Then: username = nickname, realname = nickname

**Store configuration**
- Given: Full config provided
- When: Create client
- Then: All values accessible

### Unit Tests - State

**Initially disconnected**
- Given: New client
- Then: `client.connected?` = false, `client.state` = :disconnected

**After connect**
- Given: Client connects successfully
- Then: `client.connected?` = true, `client.state` = :connected

**After quit**
- Given: Connected client quits
- Then: `client.connected?` = false

**Track nickname**
- Given: Connected as "oldnick"
- When: Nick changed to "newnick"
- Then: `client.nick` = "newnick"

**Track channels**
- Given: Connected client
- When: Join #test
- Then: `client.channels["#test"]` exists

### Unit Tests - Command Methods

**join delegates to socket**
- Given: Connected client
- When: `client.join("#test")`
- Then: "JOIN #test" sent

**privmsg delegates to socket**
- Given: Connected client
- When: `client.privmsg("#test", "Hello")`
- Then: "PRIVMSG #test :Hello" sent

### Error Handling Tests

**Connection refused**
- Given: No server on port
- When: `client.connect`
- Then: Raises connection error

**Server error numeric**
- Given: Connected client with :error handler
- When: Server sends 433 (nick in use)
- Then: Handler called with error info

## Implementation Notes

- `connect` should handle the full registration sequence
- Consider thread-safety for handlers
- Event loop reads from socket, parses messages, dispatches events
- All command methods should validate state (connected?) before sending
- Consider `connect_async` for non-blocking usage

## Dependencies

- Requires all previous features
- This is the final integration feature
