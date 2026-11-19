# What broke

The common thread: **almost nothing failed loudly.** Every failure below looked like a normal,
quiet day. The fix was rarely the code — it was finding a signal that tells "worked" apart from
"didn't run."

---

## 1. The self-restart that never once worked

**What I expected:** the nightly maintenance script restarts every agent, including the one
running it, using a detached `nohup … sleep 20; kickstart &`.

**What happened:** that agent was never restarted. Not once, for the life of the script. launchd
reaps a job's whole process group when the job exits, unless the job sets `AbandonProcessGroup`.
The "detached" child died with its parent.

**How it surfaced:** at 3:30 AM the supposedly fresh session was 14.8 hours old, and its restart
marker had never been consumed.

**Fix:** give the self-restart its own launchd job instead of a background child.

**Lesson:** "it ran without errors" and "it did the thing" are different claims. Check the effect
(session age), not the exit code.

## 2. Five agents crash-looping for a day, every health check green

**What happened:** a Claude Code update reworded a startup trust dialog. Five agents restarted
into that dialog, couldn't answer it, and crash-looped for about 25 hours.

**Why nothing caught it:** every check I had read healthy — the session existed, the process was
alive, launchd said `running`, the last exit code was fine. The one check that looked for the
dialog matched its *old* wording. And between crashes, the pane looked idle, so scheduled prompts
were "delivered" into it and logged as sent.

**The signal that did tell:** launchd's `runs` counter, the only number that only goes up.
Healthy agents sat at 25–26. The looping ones were at 2,905–3,284.

**Fix:** every scheduled send now records the run counter and warns when it jumps by more than 2
since the last send. It's keyed on a number, not on dialog text, so the next rewording can't slip
past it.

**Lesson:** health checks that test *state* ("is it running?") miss loops. A cumulative counter
catches them.

## 3. Plan mode over Telegram hangs forever

**What happened:** asked to "plan it" from my phone, an agent entered plan mode. That opens an
accept/reject dialog in the terminal — which I can't see from Telegram. The agent waited forever.

**Fix:** a `PreToolUse` hook denies plan-mode and multiple-choice tools for any agent with a
Telegram channel. Agents post plans and A/B/C questions as normal messages instead.

**Lesson:** an approval UI is part of the interface contract. If the human can't reach it, it's a
deadlock.

## 4. A busy session swallows the scheduled prompt

**What happened:** the scheduler types the prompt into tmux. If the agent is mid-task, the
keystrokes land in the middle of its work and the op is lost.

**Fix:** the trigger script waits until the pane is idle (up to a 25-minute cap) and logs
`waiting` / `SENT` to a file.

## 5. The scheduler said green, and it was wrong

Two jobs, same lesson:
- A weekly job had been **unloaded** from launchd for about six weeks. Nothing errored, because
  nothing ran.
- A daily job reported **35 runs, all exit 0** — while launchd was invoking the wrong script the
  whole time.

**Fix:** check what the scheduler actually has loaded and actually invokes
(`launchctl print …`), not just that a job "ran". Silence and exit 0 are not signals.

## 6. The CLI and the agent fight over the same Telegram bot

**What happened:** running `claude mcp list` inside an agent's shell (to list its tools) starts
every configured server — including the Telegram channel, against the same bot state directory.
When that command exits, it shuts down the live agent's message poller.

**Why it's nasty:** sending still works (it's plain HTTP), but receiving doesn't. The agent can
talk but not hear — which looks exactly like me being busy.

**Fix:** read config files instead of running the CLI from inside an agent; a liveness check that
ties the poller's PID to the agent through its environment.

## 7. Nightly restart vs. dreaming race

**What happened:** the fleet's sleep cycle runs one agent at a time, and its worst case runs past
the time dreaming starts. Injecting early can put the dreaming prompt into a session that's about
to be killed, losing the whole night silently.

**Fix:** dreaming polls until no cycle is mid-run, then waits a little longer; after a 45-minute
timeout it runs anyway, because a late dream beats a skipped one.

## 8. The memory index dropped its newest entries

**What happened:** each agent's memory index is loaded with a size cap. Past the cap it
truncates — from the end, which is where the newest entries are. The most recent lessons were the
first to disappear, silently.

**Fix:** measure the index size (`wc -c`) with an alarm well below the cap; keep index lines
short and put detail in the memory files.

## Bonus: the human side

The morning check-in used to be a Telegram message from every agent. That was a pile of messages
before breakfast. Now each agent writes a status file and one board pings me once.
