# Channel TOPIC

## Description

Implement getting and setting channel topics.

## Behavior

### Getting Topic

```ruby
client.topic("#ruby")  # Request current topic
```

Format: `TOPIC <channel>`

Server responds with:
- 332 RPL_TOPIC - The topic text
- 333 RPL_TOPICWHOTIME - Who set it and when
- 331 RPL_NOTOPIC - No topic set

### Setting Topic

```ruby
client.topic("#ruby", "Welcome to #ruby!")
client.topic("#ruby", "")  # Clear topic
```

Format: `TOPIC <channel> :<topic>`

### Topic Change Notification

When topic changes: `:nick!user@host TOPIC #channel :New topic`

### Topic Errors

- 442 ERR_NOTONCHANNEL - Not in channel (when getting)
- 482 ERR_CHANOPRIVSNEEDED - Not op (when setting protected topic)

### Events

Emit `:topic` event with:
- `channel` - Channel name
- `topic` - Topic text (may be nil if cleared)
- `setter` - Who set it (nick)
- `time` - When it was set (Time, optional)

## Models

```ruby
channel.topic        # => String or nil
channel.topic_setter # => String
channel.topic_time   # => Time
```

## Tests

### Integration Tests

**Get topic**
- Given: Client in #test which has topic
- When: `client.topic("#test")`
- Then: Receive RPL_TOPIC with topic text

**Get topic when none set**
- Given: Client in #test with no topic
- When: `client.topic("#test")`
- Then: Receive RPL_NOTOPIC

**Set topic**
- Given: Client is op in #test
- When: `client.topic("#test", "New topic")`
- Then: Receive TOPIC confirmation, topic changed

**Clear topic**
- Given: Client is op in #test with topic
- When: `client.topic("#test", "")`
- Then: Topic cleared

**Set topic without permission**
- Given: Client in #test (not op), channel has +t mode
- When: `client.topic("#test", "New topic")`
- Then: Receive 482 ERR_CHANOPRIVSNEEDED

**Receive topic change**
- Given: Client in #test with :topic handler
- When: Op changes topic
- Then: Handler called with channel, new topic, setter

### Unit Tests

**Format TOPIC get**
- Given: channel = "#test"
- When: Build TOPIC (no text)
- Then: Output = "TOPIC #test\r\n"

**Format TOPIC set**
- Given: channel = "#test", topic = "Hello"
- When: Build TOPIC
- Then: Output = "TOPIC #test :Hello\r\n"

**Format TOPIC clear**
- Given: channel = "#test", topic = ""
- When: Build TOPIC
- Then: Output = "TOPIC #test :\r\n"

**Parse TOPIC event**
- Given: `:nick!u@h TOPIC #test :New topic`
- When: Parse
- Then: event.channel = "#test", event.topic = "New topic", event.setter = "nick"

**Parse RPL_TOPIC**
- Given: `:server 332 mynick #test :The topic`
- When: Parse
- Then: channel = "#test", topic = "The topic"

**Parse RPL_TOPICWHOTIME**
- Given: `:server 333 mynick #test setter 1234567890`
- When: Parse
- Then: setter = "setter", time = Time.at(1234567890)

### State Tracking

**Update channel topic on change**
- Given: Client tracking #test
- When: TOPIC message received
- Then: channel.topic updated

**Topic from JOIN**
- Given: Client joins #test with topic
- When: JOIN completes
- Then: channel.topic populated from RPL_TOPIC

## Implementation Notes

- Topic can be received at JOIN time (RPL_TOPIC) or via TOPIC command/event
- RPL_TOPICWHOTIME time is Unix timestamp
- Some channels have +t (topic protected) - only ops can change
- Empty string topic clears it

## Dependencies

- Requires `01-message-parsing.md`
- Requires `05-event-system.md`
- Requires `07-join-part.md` (topic received at join)
