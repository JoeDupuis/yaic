# YAIC Data Model

This document describes the core data structures used in the YAIC IRC client library.

## IRC Message Structure

Every IRC message follows this format:
```
['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
```

### Message Class

```ruby
Yaic::Message
  - tags: Hash[String, String]     # Optional IRCv3 message tags
  - source: Yaic::Source or nil    # Origin of message (nil for client-sent)
  - command: String                # Command name or 3-digit numeric
  - params: Array[String]          # Command parameters (0-15+)
  - raw: String                    # Original raw message (for debugging)
```

### Source Class

Represents the origin of a message:
```ruby
Yaic::Source
  - nick: String or nil      # Nickname (nil if server)
  - user: String or nil      # Username (after !)
  - host: String or nil      # Hostname (after @)
  - raw: String              # Original source string
```

Formats:
- `servername` - Message from server
- `nick!user@host` - Full user prefix
- `nick!user` - User without host
- `nick@host` - User without username
- `nick` - Just nickname

## Connection State

```ruby
Yaic::Connection
  - state: Symbol            # :disconnected, :connecting, :registering, :connected
  - server: String           # Server hostname
  - port: Integer            # Server port (default 6697)
  - ssl: Boolean             # Use TLS/SSL
  - nickname: String         # Current nickname
  - username: String         # Username sent in USER
  - realname: String         # Realname sent in USER
  - password: String or nil  # Server password (optional)
```

### Connection States

1. `:disconnected` - Not connected to server
2. `:connecting` - TCP/TLS handshake in progress
3. `:registering` - Sent NICK/USER, awaiting welcome
4. `:connected` - Registered and ready for commands

## Channel State

```ruby
Yaic::Channel
  - name: String             # Channel name (e.g., "#ruby")
  - topic: String or nil     # Channel topic
  - topic_setter: String     # Who set the topic
  - topic_time: Time         # When topic was set
  - users: Hash[String, Set[Symbol]]  # nick => set of modes (@, +, etc.)
  - modes: Hash[Symbol, Object]       # Channel modes
```

## User State

```ruby
Yaic::User
  - nick: String
  - user: String or nil
  - host: String or nil
  - realname: String or nil
  - away: Boolean
  - away_message: String or nil
```

## Event Types

Events emitted by the client:

| Event | Payload | Description |
|-------|---------|-------------|
| `:connect` | `{server:}` | Successfully connected and registered |
| `:disconnect` | `{reason:}` | Connection closed |
| `:message` | `{source:, target:, text:}` | PRIVMSG received |
| `:notice` | `{source:, target:, text:}` | NOTICE received |
| `:join` | `{channel:, user:}` | User joined channel |
| `:part` | `{channel:, user:, reason:}` | User left channel |
| `:quit` | `{user:, reason:}` | User quit IRC |
| `:kick` | `{channel:, user:, by:, reason:}` | User kicked from channel |
| `:nick` | `{old_nick:, new_nick:}` | User changed nickname |
| `:topic` | `{channel:, topic:, setter:}` | Topic changed |
| `:mode` | `{target:, modes:, args:}` | Mode changed |
| `:raw` | `{message:}` | Any raw message (for debugging) |
| `:error` | `{numeric:, message:}` | Error from server |

## Message Length Limits

- Base message: 512 bytes (including CRLF)
- With IRCv3 tags: 512 + 8191 = 8703 bytes max
- Usable content: 510 bytes (excluding CRLF)

## Character Encoding

- Primary: UTF-8
- Fallback: Latin-1 (ISO-8859-1)
- Invalid bytes: Replace with replacement character

## Nickname Restrictions

Must NOT contain:
- SPACE (0x20)
- Comma (0x2C)
- Asterisk (0x2A)
- Question mark (0x3F)
- Exclamation mark (0x21)
- At sign (0x40)

Must NOT start with:
- Dollar (0x24)
- Colon (0x3A)
- Channel prefix (#, &)

## Channel Name Restrictions

Must start with:
- `#` (regular channel)
- `&` (local channel)

Must NOT contain:
- SPACE (0x20)
- BELL (0x07)
- Comma (0x2C)

## Numeric Reply Categories

| Range | Category |
|-------|----------|
| 001-099 | Connection/welcome |
| 200-399 | Command responses |
| 400-599 | Error responses |
