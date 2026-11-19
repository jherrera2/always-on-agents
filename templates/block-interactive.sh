#!/usr/bin/env bash
# block-interactive.sh — Claude Code PreToolUse hook.
#
# Plan mode and multiple-choice questions open a dialog in the terminal. An agent
# driven from Telegram has nobody at the terminal, so it would wait forever.
# This hook blocks those tools for Telegram-driven agents and tells the agent to
# ask in the chat instead. A normal interactive `claude` (no TELEGRAM_STATE_DIR)
# is unaffected.
#
# Register it in ~/.claude/settings.json:
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "ExitPlanMode|AskUserQuestion|EnterPlanMode",
#       "hooks": [{ "type": "command", "command": "~/bin/block-interactive.sh" }]
#     }]
#   }
#
# Exit code 2 blocks the tool call and shows stderr to the agent.

if [ -n "${TELEGRAM_STATE_DIR:-}" ]; then
  echo "You are being driven over Telegram. This tool opens a terminal dialog nobody can answer, so the session would hang. Don't use plan mode or multiple-choice prompts here: send your plan or question (with A/B/C options) as a Telegram message and wait for the reply." >&2
  exit 2
fi
exit 0
