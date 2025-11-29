#!/usr/bin/env bash
[ "$RALPH_WIGGUM_LOOP" != "true" ] && exit 0
cat << 'JSON'
{
  "decision": "block",
  "continue": true,
  "reason": "If you are blocked, confused, or need clarification, DO NOT EXIT OR STOP WORKING - use the AskUserQuestion tool and wait for a response. You cannot exit or stop until you have COMPLETED a feature or the user quit for you. If you have completed a feature (tests pass, QA passed, feature marked .done), exit by calling .claude/ralph/bin/kill-claude."
}
JSON
