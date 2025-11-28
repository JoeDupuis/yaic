# Message Parsing

## Description

Implement the core message parsing and serialization module that converts between raw IRC protocol bytes and structured Ruby objects. This is the foundation upon which all other IRC functionality is built.

## Behavior

### Parsing Incoming Messages

Parse raw IRC messages in the format:
```
['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
```

Components are parsed in order:
1. If starts with `@`, extract tags until first SPACE
2. If starts with `:`, extract source until first SPACE
3. Extract command (letters or 3-digit numeric)
4. Extract parameters (space-separated, last may have `:` prefix for trailing)

### Serializing Outgoing Messages

Convert `Yaic::Message` objects to wire format:
- NEVER include source (clients don't send source)
- Append `\r\n` to every message
- Prepend `:` to trailing parameter if it contains spaces, is empty, or starts with `:`

### Tag Parsing

Tags format: `@key1=value1;key2=value2`
- Split on `;`
- Split each on `=` for key/value
- Value may be empty
- Strip leading `@`

### Source Parsing

Parse formats:
- `servername`
- `nick!user@host`
- `nick!user`
- `nick@host`
- `nick`

### Parameter Parsing

- Split on SPACE
- Last parameter with `:` prefix is "trailing" - can contain spaces
- Strip the `:` prefix from trailing parameter

## Models

See `docs/agents/data-model.md` for:
- `Yaic::Message` structure
- `Yaic::Source` structure

## Tests

### Unit Tests - Message Parsing

**Parse simple command**
- Given: `"PING :token123\r\n"`
- When: Parse message
- Then: command = "PING", params = ["token123"]

**Parse message with source**
- Given: `":nick!user@host PRIVMSG #channel :Hello world\r\n"`
- When: Parse message
- Then: source.nick = "nick", source.user = "user", source.host = "host", command = "PRIVMSG", params = ["#channel", "Hello world"]

**Parse message with tags**
- Given: `"@id=123;time=2023-01-01 :server NOTICE * :Hello\r\n"`
- When: Parse message
- Then: tags = {"id" => "123", "time" => "2023-01-01"}, source.raw = "server"

**Parse numeric reply**
- Given: `":irc.example.com 001 mynick :Welcome\r\n"`
- When: Parse message
- Then: command = "001", params = ["mynick", "Welcome"]

**Parse message with empty trailing**
- Given: `":server CAP * LIST :\r\n"`
- When: Parse message
- Then: params = ["*", "LIST", ""]

**Parse message with colon in trailing**
- Given: `":nick PRIVMSG #chan ::-)\r\n"`
- When: Parse message
- Then: params = ["#chan", ":-)"]

**Parse message without trailing colon**
- Given: `"NICK newnick\r\n"`
- When: Parse message
- Then: command = "NICK", params = ["newnick"]

**Parse source - server only**
- Given: source string "irc.example.com"
- When: Parse source
- Then: nick = nil, host = "irc.example.com"

**Parse source - full user**
- Given: source string "dan!~d@localhost"
- When: Parse source
- Then: nick = "dan", user = "~d", host = "localhost"

**Parse source - nick only**
- Given: source string "dan"
- When: Parse source
- Then: nick = "dan", user = nil, host = nil

### Unit Tests - Message Serialization

**Serialize simple command**
- Given: Message with command = "NICK", params = ["mynick"]
- When: Serialize
- Then: Output = "NICK mynick\r\n"

**Serialize with trailing spaces**
- Given: Message with command = "PRIVMSG", params = ["#chan", "Hello world"]
- When: Serialize
- Then: Output = "PRIVMSG #chan :Hello world\r\n"

**Serialize with empty trailing**
- Given: Message with command = "TOPIC", params = ["#chan", ""]
- When: Serialize
- Then: Output = "TOPIC #chan :\r\n"

**Never include source in client messages**
- Given: Message with source set, command = "NICK", params = ["test"]
- When: Serialize
- Then: Output = "NICK test\r\n" (no source)

### Edge Cases

**Handle LF-only line endings from server**
- Given: `"PING :test\n"`
- When: Parse message
- Then: Successfully parses (compatibility mode)

**Ignore empty lines**
- Given: `"\r\n"`
- When: Parse message
- Then: Return nil or skip

**Handle multiple spaces between components**
- Given: `":server  PRIVMSG  #chan  :text\r\n"` (extra spaces)
- When: Parse message
- Then: Successfully parses

## Implementation Notes

- Use a Message class with `parse` class method and `to_s` instance method
- Source should be a separate class with parsing logic
- Consider using StringScanner for efficient parsing
- UTF-8 encoding by default, with fallback to Latin-1

## Dependencies

None - this is the foundation feature.
