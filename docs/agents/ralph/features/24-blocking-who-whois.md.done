# Blocking WHO/WHOIS

## Description

Convert `who` and `whois` methods from fire-and-forget to blocking calls that return results directly. This follows the same pattern already used by `join`, `part`, and `nick` methods.

## Behavior

### WHO Command

`who(mask, timeout: DEFAULT_OPERATION_TIMEOUT)` sends WHO command and blocks until END OF WHO (315) is received.

- Returns an array of `WhoResult` objects (one per user matching the mask)
- Returns empty array if no matches
- Raises `Yaic::TimeoutError` if timeout exceeded
- Events (`:who`) still fire for each reply (maintains backward compatibility)

### WHOIS Command

`whois(nick, timeout: DEFAULT_OPERATION_TIMEOUT)` sends WHOIS command and blocks until END OF WHOIS (318) is received.

- Returns `WhoisResult` object if user found
- Returns `nil` if user not found (401 ERR_NOSUCHNICK)
- Raises `Yaic::TimeoutError` if timeout exceeded
- Event (`:whois`) still fires (maintains backward compatibility)

### WhoResult Class

Create `lib/yaic/who_result.rb` with attributes matching the `:who` event data:

- `channel` - channel name (or "*" for non-channel queries)
- `user` - username
- `host` - hostname
- `server` - server name
- `nick` - nickname
- `away` - boolean, true if user is away
- `realname` - real name

## Models

New file: `lib/yaic/who_result.rb`

```ruby
module Yaic
  class WhoResult
    attr_reader :channel, :user, :host, :server, :nick, :away, :realname

    def initialize(channel:, user:, host:, server:, nick:, away:, realname:)
      # ...
    end
  end
end
```

## Implementation Notes

### Tracking Pending Operations

Use instance variables to track pending blocking operations:

- `@pending_who_results` - Hash of mask => array of WhoResult objects being collected
- `@pending_who_complete` - Hash of mask => boolean (true when 315 received)

The existing `@pending_whois` already tracks WHOIS, just need to add completion tracking.

### Handle Interleaving

Multiple WHO/WHOIS requests could be in flight. Track by mask/nick to handle interleaving correctly. The existing WHOIS implementation already handles this.

### Modify Handlers

- `handle_rpl_whoreply` (352): Create WhoResult, add to pending array
- `handle_rpl_endofwho` (315): Mark pending WHO complete
- `handle_rpl_endofwhois` (318): Already handled, add completion flag

### Waiting Pattern

Follow the existing pattern from `join`:

```ruby
def who(mask, timeout: DEFAULT_OPERATION_TIMEOUT)
  @pending_who_results[mask] = []
  @pending_who_complete[mask] = false

  message = Message.new(command: "WHO", params: [mask])
  @socket.write(message.to_s)

  wait_until(timeout: timeout) { @pending_who_complete[mask] }

  @pending_who_results.delete(mask)
ensure
  @pending_who_complete.delete(mask)
end
```

## Tests

### Unit Tests

**who returns array of WhoResult objects**
- Given: Mock socket returns 352 replies followed by 315
- When: `client.who("#channel")`
- Then: Returns array of WhoResult with correct attributes

**who returns empty array when no matches**
- Given: Mock socket returns only 315 (no 352 replies)
- When: `client.who("nobody")`
- Then: Returns empty array

**who raises TimeoutError on timeout**
- Given: Mock socket never returns 315
- When: `client.who("#channel", timeout: 0.1)`
- Then: Raises Yaic::TimeoutError

**who still emits :who events**
- Given: Mock socket returns 352 replies
- When: `client.who("#channel")` with event listener attached
- Then: Events fire AND method returns results

**whois returns WhoisResult**
- Given: Mock socket returns WHOIS numerics followed by 318
- When: `client.whois("nick")`
- Then: Returns WhoisResult with correct attributes

**whois returns nil for unknown nick**
- Given: Mock socket returns 401 ERR_NOSUCHNICK then 318
- When: `client.whois("nobody")`
- Then: Returns nil

**whois raises TimeoutError on timeout**
- Given: Mock socket never returns 318
- When: `client.whois("nick", timeout: 0.1)`
- Then: Raises Yaic::TimeoutError

### Integration Tests

**who channel returns all users**
- Given: Two clients connected to same channel
- When: `client1.who("#channel")`
- Then: Returns array with both users' info

**who nick returns single user**
- Given: Two clients connected
- When: `client1.who(client2_nick)`
- Then: Returns array with one WhoResult for client2

**whois returns user info**
- Given: Two clients connected
- When: `client1.whois(client2_nick)`
- Then: Returns WhoisResult with nick, user, host, realname

**whois unknown returns nil**
- Given: Client connected
- When: `client.whois("nobody_exists")`
- Then: Returns nil (not raises)

## Dependencies

None - builds on existing WHO/WHOIS handling from 14-who-whois.md
