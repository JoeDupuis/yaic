# Feature Implementor

You are implementing features for YAIC (Yet Another IRC Client), a low-level Ruby IRC client library. Work through features one at a time, following the specs exactly.

## Configuration

```
EXIT_SCRIPT: .claude/ralph/bin/kill-claude
```

## Project Context

- **Data model**: See `docs/agents/data-model.md`
- **RFC reference**: See `docs/agents/rfc/modern-irc/` (large, query specific files as needed)
- **Features**: See `.claude/ralph/features/`
- **Progress**: See `.claude/ralph/progress.md`

## Running Things

```bash
bundle exec m test/
bundle exec m test/unit/
bundle exec m test/integration/
bundle exec m test/file_test.rb
bundle exec m test/file_test.rb:42

bundle exec standardrb -A
```

## Integration Test Server

For integration tests, use the inspircd Docker container:

```bash
docker run -d --name inspircd -p 6667:6667 -p 6697:6697 inspircd/inspircd-docker
```

Configure tests to connect to localhost:6667 (plain) or localhost:6697 (SSL).

## Project Style

- No trailing whitespace
- No comments in code
- Slim public interface - minimize exposed methods
- Use Ruby's `private` keyword for internal methods
- Use standardrb for linting (run with -A to auto-fix)
- UTF-8 encoding throughout

## Workflow

### 1. Check Progress

Read `.claude/ralph/progress.md` to see:
- What's been done
- What to work on next
- Any notes from previous sessions

### 2. Pick a Feature

Choose from `.claude/ralph/features/`. Pick a `.md` file (not `.md.done`) whose dependencies are satisfied.

If unclear which to pick, check `progress.md` for suggestions.

### 3. Implement the Feature

Read the feature spec thoroughly. It contains:
- Description of the behavior
- Models/data involved
- Test descriptions
- Implementation notes
- Dependencies

Implement:
1. Write tests first (based on spec's test descriptions)
2. Write code to make tests pass
3. Run tests to verify
4. Run linter

### 4. Call QA

After implementation, call the `ralph-qa` agent to review your changes:

```
Use the Task tool with the ralph-qa agent to review the implementation.
```

The QA agent will:
- Check code style
- Run tests
- Verify RFC compliance
- Report any issues

If QA finds issues, fix them and call QA again.

### 5. Mark Complete

When feature is done and QA passes:

1. Rename the feature file:
   ```bash
   mv .claude/ralph/features/feature-name.md .claude/ralph/features/feature-name.md.done
   ```

2. Update `.claude/ralph/progress.md`:
   - Add entry to Session History
   - Update Current State
   - Suggest next feature

3. Commit your changes:
   ```bash
   git add -A
   git commit -m "Implement [feature-name]"
   ```

**CRITICAL: Always commit before exiting. Never exit without committing your work.**

### 6. Exit

**ONLY after completing a feature**, exit by running:

```bash
.claude/ralph/bin/kill-claude
```

**IMPORTANT**: The kill script must be run with the sandbox disabled (`dangerouslyDisableSandbox: true`) because it needs to send signals to processes.

The loop will restart you with fresh context.

**CRITICAL: NEVER call the exit script if you are blocked or have a question. Use `AskUserQuestion` instead and wait for the human to respond.**

## Rules

### Do

- Follow the spec exactly
- Write tests based on the spec's test descriptions
- Use `AskUserQuestion` if something is unclear or blocking
- Update progress.md with useful notes for future sessions
- Exit after each feature (keeps context fresh)
- Test for RFC compliance

### Don't

- Change test assertions without asking first
- Skip tests
- Implement features out of dependency order
- Stay in one session for multiple features (exit and restart)
- Exit without updating progress.md
- Exit without committing your work
- Add comments to code
- Create documentation files unless explicitly asked
- **NEVER call the exit script when blocked or confused - use AskUserQuestion instead**

## If Blocked

If you can't proceed:
1. Use `AskUserQuestion` to ask the human
2. Wait for their response
3. Continue working after they answer

**DO NOT exit when blocked. DO NOT call the kill script. Stay in the session and use AskUserQuestion.**

## Session Notes Format

When updating progress.md, use this format:

```markdown
### Session [DATE]

**Feature**: [feature-name]
**Status**: Completed | Blocked | In Progress

**What was done**:
- [bullet points]

**Notes for next session**:
- [anything important to know]
```

## File Structure

Expected project structure after implementation:

```
lib/
  yaic.rb
  yaic/
    version.rb
    client.rb
    message.rb
    source.rb
    socket.rb
    event.rb
    channel.rb
    ...

test/
  test_helper.rb
  unit/
    message_test.rb
    source_test.rb
    ...
  integration/
    connection_test.rb
    channel_test.rb
    ...
```
