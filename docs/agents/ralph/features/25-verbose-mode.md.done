# Verbose Mode

## Description

Add a `verbose:` option to the Client constructor that outputs debug information about connection state changes and blocking operations. Helps developers understand what the client is doing.

## Behavior

### Enabling Verbose Mode

```ruby
client = Yaic::Client.new(
  server: "irc.example.com",
  nick: "mynick",
  verbose: true  # defaults to false
)
```

### What Gets Logged

**Connection State Changes**
- When connecting starts
- When connected successfully
- When disconnected (including reason if available)
- When connection state changes (registering, etc.)

**Blocking Operations**
- When waiting for an operation to complete (join, part, nick, who, whois)
- When the wait completes

### Output Format

Simple, readable format to STDERR:

```
[YAIC] Connecting to irc.example.com:6697 (SSL)...
[YAIC] Connected, registering...
[YAIC] Registration complete
[YAIC] Joining #channel...
[YAIC] Joined #channel
[YAIC] Sending WHO #channel...
[YAIC] WHO complete (3 results)
[YAIC] Sending WHOIS nick...
[YAIC] WHOIS complete
[YAIC] Disconnected
```

### Output Destination

Use `$stderr.puts` for output. This keeps it separate from application output and works well with logging redirection.

## Implementation Notes

### Add verbose attribute

```ruby
def initialize(server:, port: 6697, nick:, user: nil, realname: nil, ssl: true, verbose: false)
  @verbose = verbose
  # ...
end
```

### Add logging helper

```ruby
private

def log(message)
  return unless @verbose
  $stderr.puts "[YAIC] #{message}"
end
```

### Add logging calls

In `connect`:
```ruby
log "Connecting to #{@server}:#{@port}#{@ssl ? ' (SSL)' : ''}..."
```

After registration complete (in handler for 001):
```ruby
log "Connected"
```

In `set_state`:
```ruby
log "State: #{state}" # or more friendly messages per state
```

In `join`:
```ruby
log "Joining #{channel}..."
# after wait_until
log "Joined #{channel}"
```

In `part`:
```ruby
log "Parting #{channel}..."
log "Parted #{channel}"
```

In `who`:
```ruby
log "Sending WHO #{mask}..."
# after wait_until
log "WHO complete (#{results.size} results)"
```

In `whois`:
```ruby
log "Sending WHOIS #{nick}..."
# after wait_until
log "WHOIS complete"
```

In disconnect handler:
```ruby
log "Disconnected"
```

## Tests

### Unit Tests

**verbose false produces no output**
- Given: Client created with `verbose: false` (default)
- When: Client connects and performs operations
- Then: No output to stderr

**verbose true logs connection**
- Given: Client created with `verbose: true`
- When: Client connects
- Then: Stderr contains "[YAIC] Connecting to" message

**verbose true logs state changes**
- Given: Client created with `verbose: true`
- When: Client connects successfully
- Then: Stderr contains "[YAIC] Connected" message

**verbose true logs join**
- Given: Connected client with `verbose: true`
- When: `client.join("#channel")`
- Then: Stderr contains "[YAIC] Joining #channel..." and "[YAIC] Joined #channel"

**verbose true logs who**
- Given: Connected client with `verbose: true`
- When: `client.who("#channel")`
- Then: Stderr contains "[YAIC] Sending WHO" and "[YAIC] WHO complete"

**verbose true logs whois**
- Given: Connected client with `verbose: true`
- When: `client.whois("nick")`
- Then: Stderr contains "[YAIC] Sending WHOIS" and "[YAIC] WHOIS complete"

### Integration Tests

**verbose mode produces expected output sequence**
- Given: Client with `verbose: true`
- When: Connect, join channel, who channel, disconnect
- Then: Stderr output matches expected sequence of log messages

## Dependencies

- 24-blocking-who-whois.md (for WHO/WHOIS logging)
