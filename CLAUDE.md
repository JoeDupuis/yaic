# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Yaic (Yet Another IRC Client) is a Ruby gem that provides an IRC client library. It handles IRC protocol messaging, event handling, channel management, and connection state.

**Minimum Ruby version: 3.2**

## Commands

### Testing
```bash
rake test              # Run all tests
rake test_unit         # Run unit tests only
rake test_integration  # Run integration tests only
m test/unit/message_test.rb:42  # Run single test by line number
```

### Linting
```bash
bundle exec standardrb -A  # Run linter with auto-fix
```

### Security
```bash
bin/brakeman  # Run security scanner
```

### Integration Test Setup
Integration tests require a running IRC server (InspIRCd via Docker):
```bash
bin/start-irc-server  # Start IRC server container (ports 6667/6697)
bin/stop-irc-server   # Stop IRC server container
```

## Architecture

### Core Components

- **Client** (`lib/yaic/client.rb`): Main IRC client class. Manages connection state, handles incoming IRC messages, maintains channel/user state, and provides event emission system with `on`/`off` handlers.

- **Message** (`lib/yaic/message.rb`): Parses and serializes IRC protocol messages (source, command, params).

- **Socket** (`lib/yaic/socket.rb`): TCP socket wrapper with SSL support.

- **Channel** (`lib/yaic/channel.rb`): Tracks channel state including users, modes, and topic.

- **Event** (`lib/yaic/event.rb`): Event objects emitted for IRC events (`:message`, `:join`, `:part`, etc.).

### Event System

Client uses an event-based model:
```ruby
client.on(:message) { |event| handle_message(event) }
client.on(:join) { |event| handle_join(event) }
```

Events: `:raw`, `:connect`, `:disconnect`, `:message`, `:notice`, `:join`, `:part`, `:quit`, `:kick`, `:nick`, `:topic`, `:mode`, `:names`, `:who`, `:whois`, `:error`

### Test Structure

- `test/unit/` - Unit tests mocking the socket layer
- `test/integration/` - Integration tests against real IRC server (InspIRCd)
