# Event System

## Description

Implement the event callback system that allows user code to react to IRC events. This is the primary interface for users of the library.

## Behavior

### Registering Handlers

```ruby
client.on(:message) { |event| ... }
client.on(:join) { |event| ... }
client.on(:raw) { |message| ... }
```

Multiple handlers can be registered for the same event. They are called in order of registration.

### Event Dispatch

When an IRC message is received:
1. Parse the message
2. Determine event type(s) to emit
3. Build event payload
4. Call each registered handler with payload
5. Optionally emit `:raw` for every message

### Event Types

| Event | Trigger | Payload |
|-------|---------|---------|
| `:connect` | 001 RPL_WELCOME | `{server:}` |
| `:disconnect` | Connection closed | `{reason:}` |
| `:message` | PRIVMSG | `{source:, target:, text:}` |
| `:notice` | NOTICE | `{source:, target:, text:}` |
| `:join` | JOIN | `{channel:, user:}` |
| `:part` | PART | `{channel:, user:, reason:}` |
| `:quit` | QUIT | `{user:, reason:}` |
| `:kick` | KICK | `{channel:, user:, by:, reason:}` |
| `:nick` | NICK | `{old_nick:, new_nick:}` |
| `:topic` | TOPIC / 332 | `{channel:, topic:, setter:}` |
| `:mode` | MODE | `{target:, modes:, params:}` |
| `:error` | 4xx/5xx | `{numeric:, message:}` |
| `:raw` | Any message | `{message:}` |

### Handler Signature

```ruby
client.on(:message) do |event|
  event.source   # Yaic::Source - who sent it
  event.target   # String - channel or nick
  event.text     # String - message content
end
```

### Error Handling in Handlers

If a handler raises an exception:
- Log the error
- Continue calling remaining handlers
- Do not crash the event loop

## Models

```ruby
Yaic::Event
  - type: Symbol
  - attributes: Hash
  - message: Yaic::Message (original parsed message)
  - method_missing for attribute access
```

## Tests

### Unit Tests - Handler Registration

**Register single handler**
- Given: New client
- When: Register handler for :message
- Then: Handler is stored

**Register multiple handlers for same event**
- Given: New client
- When: Register 3 handlers for :message
- Then: All 3 handlers stored in order

**Register handlers for different events**
- Given: New client
- When: Register handlers for :message, :join, :part
- Then: Each event has its handlers

### Unit Tests - Event Dispatch

**Dispatch calls all handlers**
- Given: 3 handlers registered for :message
- When: Dispatch :message event
- Then: All 3 handlers called in order

**Dispatch with correct payload**
- Given: Handler registered for :message
- When: PRIVMSG received from "nick!user@host" to "#chan" with text "hello"
- Then: Handler receives event with source.nick="nick", target="#chan", text="hello"

**Handler exception doesn't stop others**
- Given: 3 handlers, second one raises
- When: Dispatch event
- Then: First and third handlers still called

**Unknown event type**
- Given: No handlers registered for :foo
- When: Dispatch :foo event
- Then: No error, silently ignored

### Unit Tests - Event Type Detection

**PRIVMSG triggers :message**
- Given: PRIVMSG message received
- When: Determine event type
- Then: Returns :message

**NOTICE triggers :notice**
- Given: NOTICE message received
- When: Determine event type
- Then: Returns :notice

**JOIN triggers :join**
- Given: JOIN message received
- When: Determine event type
- Then: Returns :join

**001 triggers :connect**
- Given: 001 numeric received
- When: Determine event type
- Then: Returns :connect

**4xx/5xx triggers :error**
- Given: 433 numeric received
- When: Determine event type
- Then: Returns :error with numeric in payload

### Integration Tests

**End-to-end message event**
- Given: Connected client with :message handler
- When: Another client sends PRIVMSG
- Then: Handler called with correct source, target, text

**End-to-end join event**
- Given: Connected client with :join handler
- When: Client joins #test
- Then: Handler called with channel="#test", user=self

**Multiple events from one message**
- Given: Connected client with :raw and :message handlers
- When: PRIVMSG received
- Then: Both :raw and :message handlers called

## Implementation Notes

- Use simple array of [event_type, block] pairs
- Consider using a Queue for thread-safe dispatch
- Events should be fired synchronously (blocking until all handlers complete)
- Provide `client.off(:event)` to remove handlers if needed

## Dependencies

- Requires `01-message-parsing.md` (to parse incoming messages)
