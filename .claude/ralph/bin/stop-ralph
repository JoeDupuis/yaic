#!/usr/bin/env bash
CONTROL_FILE=".claude/ralph/loop-control"
PID_FILE=".claude/ralph/pid"

if [ ! -f "$CONTROL_FILE" ]; then
    echo "No running loop found."
    exit 1
fi

rm "$CONTROL_FILE"

if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
fi

echo "Loop stopped."
