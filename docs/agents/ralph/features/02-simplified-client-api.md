# Simplified Client API

## Description

The current Client API is broken. Users must:
- Call `client.on_socket_connected` manually (insane)
- Access internal socket via `instance_variable_get(:@socket)`
- Manually loop calling `socket.read`, `Message.parse`, `client.handle_message`
- Build custom `wait_for_*` helpers for every operation

The spec at `15-client-api.md.done` described the correct interface but the implementation didn't deliver. Fix it.

## Target API

```ruby
client = Yaic::Client.new(
  server: "irc.libera.chat",
  port: 6697,
  ssl: true,
  nickname: "mynick"
)

client.on(:message) { |event| puts event.text }
client.connect

client.join("#ruby")
client.privmsg("#ruby", "Hello!")
client.part("#ruby")
client.quit
```

That's it. All methods block until the operation completes. No bangs, no timeout params, no manual socket handling.

## Behavior

### All Operations Block

| Method | Blocks until |
|--------|--------------|
| `connect` | 001 RPL_WELCOME received |
| `join(channel)` | Channel appears in `@channels` |
| `part(channel)` | Channel removed from `@channels` |
| `nick(new)` | Nick change confirmed |
| `quit` | Disconnect complete |

### `connect` Method

Current (broken):
```ruby
client.connect
client.on_socket_connected  # User must call this!
socket = client.instance_variable_get(:@socket)  # Insane
# Manual loop...
```

After:
```ruby
client.connect  # Does everything, blocks until registered
```

Internally `connect` must:
1. Create socket and connect (blocking with TCPSocket after feature 01)
2. Send NICK/USER registration
3. Start read loop (background thread)
4. Wait for 001 RPL_WELCOME
5. Set state to `:connected`
6. Return

### Read Loop

Background thread that runs continuously:
```ruby
loop do
  raw = @socket.read
  if raw
    message = Message.parse(raw)
    handle_message(message) if message
  end
  break if @state == :disconnected
  sleep 0.001  # Prevent busy-wait when no data
end
```

### Internal Timeouts

Timeouts are an internal concern. Use sensible defaults:
- `connect`: 30 seconds
- `join`/`part`/`nick`: 10 seconds

Raise an error if exceeded. Users don't need to think about this.

### Thread Safety

- `@handlers` hash needs mutex protection for `on`/`off` during loop
- `@state` writes should be protected
- `@channels` needs mutex if accessed from handlers

### Remove Exposed Internals

- Remove `on_socket_connected` - internal use only
- `handle_message` can stay public for testing but document as internal
- Socket should never need to be accessed by users

## Tests

### Integration Tests - The Dream

After this feature, integration tests should look like:

```ruby
def test_two_clients_chat
  client1 = Yaic::Client.new(server: "localhost", port: 6667, nickname: "alice")
  client2 = Yaic::Client.new(server: "localhost", port: 6667, nickname: "bob")

  received = []
  client2.on(:message) { |e| received << e }

  client1.connect
  client2.connect

  client1.join("#test")
  client2.join("#test")

  client1.privmsg("#test", "Hello Bob!")
  sleep 0.5  # Let message arrive

  assert_equal 1, received.size
  assert_equal "Hello Bob!", received.first.text
ensure
  client1&.quit
  client2&.quit
end
```

No more:
- `instance_variable_get`
- Manual read loops
- Custom wait helpers
- `on_socket_connected`

### Unit Tests

**connect blocks until registered**
- Given: Mock socket that returns 001 after NICK/USER
- When: `client.connect`
- Then: Returns only after state is `:connected`

**connect handles nick collision**
- Given: Mock socket returns 433 then 001
- When: `client.connect`
- Then: Retries with underscore, eventually connects

**events fire from background thread**
- Given: Connected client with :message handler
- When: Server sends PRIVMSG
- Then: Handler called without user intervention

**quit stops the read loop**
- Given: Connected client
- When: `client.quit`
- Then: Background thread terminates cleanly

**on/off are thread-safe**
- Given: Read loop running
- When: Add handler from different thread
- Then: No race condition, handler works

**join blocks until confirmed**
- Given: Connected client
- When: `client.join("#test")`
- Then: Returns only after channel appears in `@channels`

**part blocks until confirmed**
- Given: Client in #test
- When: `client.part("#test")`
- Then: Returns only after channel removed from `@channels`

**nick blocks until confirmed**
- Given: Connected client
- When: `client.nick("newnick")`
- Then: Returns only after `@nick` updated

### Simplify Existing Integration Tests

All existing integration tests get dramatically simpler. Delete all the helper methods:
- `wait_for_connection`
- `wait_for_join`
- `wait_for_part`

Before:
```ruby
client.connect
client.on_socket_connected
socket = client.instance_variable_get(:@socket)
wait_for_connection(client, socket)
client.join(@test_channel)
wait_for_join(client, socket, @test_channel)
```

After:
```ruby
client.connect
client.join(@test_channel)
```

## Implementation Notes

### Structure

```ruby
def connect
  @socket = Socket.new(@server, @port, ssl: @ssl)
  @socket.connect
  send_registration
  @state = :registering
  start_read_loop
  wait_until { @state == :connected }
end

def join(channel, key = nil)
  params = key ? [channel, key] : [channel]
  message = Message.new(command: "JOIN", params: params)
  @socket.write(message.to_s)
  wait_until { @channels.key?(channel) }
end

def part(channel, reason = nil)
  params = reason ? [channel, reason] : [channel]
  message = Message.new(command: "PART", params: params)
  @socket.write(message.to_s)
  wait_until { !@channels.key?(channel) }
end

def nick(new_nick)
  message = Message.new(command: "NICK", params: [new_nick])
  @socket.write(message.to_s)
  wait_until { @nick == new_nick }
end

private

def wait_until(timeout: 10)
  deadline = Time.now + timeout
  until yield
    raise "Operation timeout" if Time.now > deadline
    sleep 0.01
  end
end

def start_read_loop
  @read_thread = Thread.new do
    loop do
      break if @state == :disconnected
      process_incoming
    end
  end
end

def process_incoming
  raw = @socket.read
  return sleep(0.001) unless raw

  message = Message.parse(raw)
  handle_message(message) if message
rescue => e
  emit(:error, nil, exception: e)
end
```

### Cleanup on Quit

```ruby
def quit(reason = nil)
  params = reason ? [reason] : []
  message = Message.new(command: "QUIT", params: params)
  @socket.write(message.to_s)
  @channels.clear
  @state = :disconnected
  @read_thread&.join(5)
  @socket&.disconnect
  emit(:disconnect, nil)
end
```

### Graceful Error Handling

If socket dies unexpectedly:
- Set state to `:disconnected`
- Emit `:disconnect` event with error info
- Stop read loop

## Documentation

Create `README.md` with:

1. **Installation** - gem install / Gemfile
2. **Quick Start** - 10-line example that works
3. **Events** - List all events with their attributes
4. **Commands** - All IRC commands with examples
5. **Threading** - Brief note that a background thread handles reads

Keep it concise. The API should be obvious from the examples.

## Dependencies

- Requires `01-tcpsocket-refactor.md` (blocking connect simplifies this)
