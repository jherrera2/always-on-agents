#!/usr/bin/env bash
# trigger.sh — type a scheduled prompt into an agent's tmux session.
#
#   trigger.sh <agent> "<prompt>"
#
# Called by launchd (see scheduled-op.plist). It:
#   1. records launchd's restart counter for the agent and warns on a jump
#      (a crash-looping agent looks idle between crashes — see docs/what-broke.md);
#   2. waits for the agent to be idle, so the prompt doesn't land mid-task;
#   3. types the prompt, then Enter as a separate keystroke;
#   4. logs every step, so "never ran" and "chose to skip" can be told apart later.
#
# Assumes one tmux server per agent (`tmux -L <agent>`) with a session named
# claude-<agent>. Override with TRIGGER_SOCKET / TRIGGER_SESSION — that is also how
# you test this against a scratch session instead of a live agent:
#   tmux -L scratch new-session -d -s sink
#   TRIGGER_SOCKET=scratch TRIGGER_SESSION=sink ./trigger.sh test "hello"

set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

AGENT="${1:?usage: trigger.sh <agent> \"<prompt>\"}"
PROMPT="${2:?usage: trigger.sh <agent> \"<prompt>\"}"

SOCKET="${TRIGGER_SOCKET:-$AGENT}"
SESSION="${TRIGGER_SESSION:-claude-$AGENT}"
LABEL="${TRIGGER_LABEL:-com.example.agent.$AGENT}"
LOG="${TRIGGER_LOG:-$HOME/.local/state/agent-triggers/$AGENT.log}"
POLL="${TRIGGER_POLL:-30}"          # seconds between idle checks
MAX_WAIT="${TRIGGER_MAX_WAIT:-1500}" # give up waiting after 25 min and send anyway

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# 1. Restart counter. `runs` only ever goes up; a big jump between two triggers
#    means the agent has been restarting, even if its pane looks idle right now.
runs="$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | awk '/^[[:space:]]*runs =/{print $3; exit}')"
runs_file="${LOG%.log}.runs"
if [ -n "$runs" ]; then
  prev="$(cat "$runs_file" 2>/dev/null || echo "$runs")"
  echo "$runs" > "$runs_file"
  if [ $((runs - prev)) -gt 2 ]; then
    log "WARNING: $LABEL restarted $((runs - prev)) times since last trigger ($prev -> $runs); a SENT below is unproven"
  fi
fi

if ! tmux -L "$SOCKET" has-session -t "$SESSION" 2>/dev/null; then
  log "ERROR: no session $SESSION on socket $SOCKET; '$PROMPT' NOT sent"
  exit 1
fi

# 2. Busy = Claude Code's "esc to interrupt" footer is showing. Only the last few
#    non-blank lines are checked, so text on screen that merely mentions the phrase
#    doesn't count. Adjust the marker if your version shows something different.
busy() {
  tmux -L "$SOCKET" capture-pane -p -t "$SESSION" 2>/dev/null \
    | grep -v '^[[:space:]]*$' | tail -n 3 | grep -q 'esc to interrupt'
}

waited=0
while busy && [ "$waited" -lt "$MAX_WAIT" ]; do
  [ "$waited" -eq 0 ] && log "waiting: agent busy, holding '$PROMPT'"
  sleep "$POLL"
  waited=$((waited + POLL))
done
busy && log "WARNING: still busy after ${waited}s; sending anyway (late beats skipped)"

# 3. Text and Enter as separate keystrokes, with a pause, so the Enter isn't
#    swallowed while the prompt is still being pasted in.
tmux -L "$SOCKET" send-keys -t "$SESSION" "$PROMPT"
sleep 1
tmux -L "$SOCKET" send-keys -t "$SESSION" Enter

# 4.
log "SENT '$PROMPT' (waited ${waited}s, runs=${runs:-?})"
