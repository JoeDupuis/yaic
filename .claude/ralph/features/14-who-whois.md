# WHO and WHOIS

## Description

Implement user information queries. WHO lists users matching criteria, WHOIS provides detailed info about a specific user.

## Behavior

### WHO Command

```ruby
client.who("#ruby")    # List users in channel
client.who("nick")     # Get info on specific user
```

Format: `WHO <mask>`

### WHO Response

- 352 RPL_WHOREPLY - One per matching user
- 315 RPL_ENDOFWHO - End of list

RPL_WHOREPLY format:
`:server 352 mynick #chan ~user host server nick H :0 realname`

Fields:
- channel or `*`
- username
- host
- server
- nick
- flags: H (here) or G (gone/away), optionally `*` (ircop)
- hopcount and realname (after colon)

### WHOIS Command

```ruby
client.whois("dan")
```

Format: `WHOIS <nick>`

### WHOIS Response

Common numerics:
- 311 RPL_WHOISUSER - `nick user host * :realname`
- 319 RPL_WHOISCHANNELS - Channel list
- 312 RPL_WHOISSERVER - Server info
- 317 RPL_WHOISIDLE - Idle time
- 330 RPL_WHOISACCOUNT - Account name (if identified)
- 318 RPL_ENDOFWHOIS - End of WHOIS

### WHOIS Errors

- 401 ERR_NOSUCHNICK - Nick not found
- 318 RPL_ENDOFWHOIS - Still sent on error

### Events

For WHO, can emit individual results or collected batch.

For WHOIS, collect all numerics until ENDOFWHOIS, then emit `:whois` event with aggregated data.

## Models

```ruby
Yaic::WhoisResult
  - nick: String
  - user: String
  - host: String
  - realname: String
  - channels: Array[String]
  - server: String
  - idle: Integer (seconds)
  - signon: Time
  - account: String or nil
  - away: String or nil
```

## Tests

### Integration Tests - WHO

**WHO channel**
- Given: Client in #test with users
- When: `client.who("#test")`
- Then: Receive RPL_WHOREPLY for each user, then RPL_ENDOFWHO

**WHO specific nick**
- Given: "target" is online
- When: `client.who("target")`
- Then: Receive single RPL_WHOREPLY

**WHO non-existent**
- Given: No such channel/user
- When: `client.who("nobody")`
- Then: Receive only RPL_ENDOFWHO (empty results)

### Integration Tests - WHOIS

**WHOIS user**
- Given: "target" is online
- When: `client.whois("target")`
- Then: Receive RPL_WHOISUSER, RPL_WHOISSERVER, RPL_ENDOFWHOIS

**WHOIS with channels**
- Given: "target" is in channels
- When: `client.whois("target")`
- Then: RPL_WHOISCHANNELS shows their channels

**WHOIS non-existent**
- Given: No such nick
- When: `client.whois("nobody")`
- Then: Receive 401 ERR_NOSUCHNICK, then RPL_ENDOFWHOIS

**WHOIS away user**
- Given: "target" is away
- When: `client.whois("target")`
- Then: Receive 301 RPL_AWAY with away message

### Unit Tests - WHO

**Parse RPL_WHOREPLY**
- Given: `:server 352 me #chan ~user host srv nick H :0 Real Name`
- When: Parse
- Then: channel="#chan", user="~user", nick="nick", realname="Real Name", away=false

**Parse RPL_WHOREPLY away**
- Given: `:server 352 me #chan ~user host srv nick G :0 Name`
- When: Parse
- Then: away=true (G flag)

**Format WHO**
- Given: mask = "#test"
- When: Build WHO
- Then: Output = "WHO #test\r\n"

### Unit Tests - WHOIS

**Parse RPL_WHOISUSER**
- Given: `:server 311 me nick ~user host * :Real Name`
- When: Parse
- Then: nick="nick", user="~user", host="host", realname="Real Name"

**Parse RPL_WHOISCHANNELS**
- Given: `:server 319 me nick :#chan1 @#chan2 +#chan3`
- When: Parse
- Then: channels=["#chan1", "#chan2", "#chan3"] with modes noted

**Parse RPL_WHOISIDLE**
- Given: `:server 317 me nick 300 1234567890 :seconds idle`
- When: Parse
- Then: idle=300, signon=Time.at(1234567890)

**Parse RPL_WHOISACCOUNT**
- Given: `:server 330 me nick account :is logged in as`
- When: Parse
- Then: account="account"

**Format WHOIS**
- Given: nick = "target"
- When: Build WHOIS
- Then: Output = "WHOIS target\r\n"

### Collection Tests

**Collect WHOIS parts**
- Given: WHOIS in progress
- When: RPL_WHOISUSER, RPL_WHOISCHANNELS, RPL_WHOISSERVER, RPL_ENDOFWHOIS received
- Then: Single :whois event with all data

**Handle interleaved messages**
- Given: WHOIS in progress
- When: Other messages arrive between WHOIS numerics
- Then: WHOIS data still collected correctly

## Implementation Notes

- WHOIS numerics may be interleaved with other messages
- Buffer WHOIS results until ENDOFWHOIS
- Implement timeout for WHOIS (server may not respond)
- RPL_WHOISCHANNELS may have mode prefixes (@, +)
- WHO visibility affected by +i mode

## Dependencies

- Requires `01-message-parsing.md`
- Requires `05-event-system.md`
