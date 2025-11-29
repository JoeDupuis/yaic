#!/usr/bin/env bash
[ "$RALPH_WIGGUM_LOOP" != "true" ] && exit 0
echo $PPID > "$CLAUDE_PROJECT_DIR/.claude/ralph/pid"
