# Yaic

Yet Another IRC Client - A Ruby IRC client library.

## Installation

Add to your Gemfile:

```ruby
gem "yaic"
```

Or install directly:

```bash
gem install yaic
```

## Quick Start

```ruby
require "yaic"

client = Yaic::Client.new(
  server: "irc.libera.chat",
  port: 6697,
  ssl: true,
  nickname: "mynick",
  username: "myuser",
  realname: "My Real Name"
)

client.on(:message) { |event| puts "#{event.source.nick}: #{event.text}" }

client.connect
client.join("#ruby")
client.privmsg("#ruby", "Hello!")
client.quit
```

## Events

Subscribe to events with `on`:

```ruby
client.on(:message) { |event| ... }
client.on(:join) { |event| ... }
```

Unsubscribe with `off`:

```ruby
client.off(:message)
```

| Event | Attributes |
|-------|------------|
| `:raw` | `message` - Raw IRC message |
| `:connect` | `server` - Server name |
| `:disconnect` | - |
| `:message` | `source`, `target`, `text` |
| `:notice` | `source`, `target`, `text` |
| `:join` | `channel`, `user` |
| `:part` | `channel`, `user`, `reason` |
| `:quit` | `user`, `reason` |
| `:kick` | `channel`, `user`, `by`, `reason` |
| `:nick` | `old_nick`, `new_nick` |
| `:topic` | `channel`, `topic`, `setter` |
| `:mode` | `target`, `modes`, `args` |
| `:names` | `channel`, `users` |
| `:who` | `channel`, `user`, `host`, `server`, `nick`, `away`, `realname` |
| `:whois` | `result` (WhoisResult object) |
| `:error` | `numeric`, `message` |

## Commands

```ruby
client.connect                    # Connect and register
client.quit("Goodbye")            # Disconnect with optional message

client.join("#channel")           # Join a channel
client.join("#channel", "key")    # Join with key
client.part("#channel")           # Leave a channel
client.part("#channel", "reason") # Leave with reason

client.privmsg("#channel", "Hi")  # Send message to channel
client.privmsg("nick", "Hello")   # Send private message
client.msg("#channel", "Hi")      # Alias for privmsg
client.notice("#channel", "Info") # Send notice

client.nick("newnick")            # Change nickname
client.topic("#channel")          # Request topic
client.topic("#channel", "New")   # Set topic
client.kick("#channel", "nick")   # Kick user
client.mode("#channel", "+o", "nick") # Set mode

client.who("#channel")            # WHO query
client.whois("nick")              # WHOIS query
client.names("#channel")          # NAMES query
```

## Threading

The client spawns a background thread to read incoming messages. Event handlers are called from this thread. All public methods are thread-safe.

## Channel State

Access joined channels:

```ruby
client.channels["#ruby"]           # => Channel object
client.channels["#ruby"].users     # => {"nick" => Set[:op, :voice], ...}
client.channels["#ruby"].topic     # => "Ruby programming"
client.channels["#ruby"].modes     # => {:moderated => true, ...}
```

## Development

```bash
rake test              # Run all tests
rake test_unit         # Run unit tests only
rake test_integration  # Run integration tests (requires IRC server)
bundle exec standardrb -A  # Run linter
```

## License

MIT License
