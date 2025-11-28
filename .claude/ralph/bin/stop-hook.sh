#!/usr/bin/env bash
[ "$RALPH_WIGGUM_LOOP" != "true" ] && exit 0
cat << 'JSON'
{
  "decision": "block",
  "continue": true,
  "reason": "You cannot exit until you have COMPLETED a feature. If you have completed a feature (tests pass, QA passed, feature marked .done), exit by calling .claude/ralph/bin/kill-claude. If you are blocked, confused, or need clarification, DO NOT EXIT - use the AskUserQuestion tool and wait for a response."
}
JSON
