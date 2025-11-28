# Progress Log

## Current State

Project not yet started. Begin with `01-message-parsing.md`.

## Feature Order

Features should be implemented in this order (dependencies noted):

1. `01-message-parsing.md` - No deps, foundation for everything
2. `02-connection-socket.md` - Depends on 01
3. `03-registration.md` - Depends on 01, 02
4. `04-ping-pong.md` - Depends on 01, 02, 03
5. `05-event-system.md` - Depends on 01
6. `06-privmsg-notice.md` - Depends on 01-05
7. `07-join-part.md` - Depends on 01-05
8. `08-quit.md` - Depends on 01, 02, 05
9. `09-nick-change.md` - Depends on 01, 02, 03, 05
10. `10-topic.md` - Depends on 07
11. `11-kick.md` - Depends on 07
12. `12-names.md` - Depends on 07
13. `13-mode.md` - Depends on 07
14. `14-who-whois.md` - Depends on 01, 05
15. `15-client-api.md` - Depends on ALL (final integration)

---

## Session History

_No sessions yet._

---

## Suggested Next Feature

Start with `01-message-parsing.md` - This is the foundation that all other features build upon. It implements the core IRC message parsing and serialization, converting between raw protocol bytes and structured Ruby objects.
