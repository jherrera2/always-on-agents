# Set it up yourself

> Steps are macOS + launchd + Telegram, which is what I run. Linux works the same way
> with systemd in place of launchd.

## Credit first

The per-agent launcher pattern (launchd/systemd → a per-agent tmux server → `claude` with a
channel plugin, plus a health check on the bridge process) comes from
[jesung/claude-persistent-agents](https://github.com/jesung/claude-persistent-agents).
Start there for the launcher itself (MIT-licensed, per its README). This guide covers what I
added on top: scheduled prompts, shared memory between agents, the nightly cycle, and the
guardrails. The templates in this repo are my own; none of that repo's code is copied here.

## What you need

- A machine that stays on (mine is a Mac mini).
- [Claude Code](https://claude.com/claude-code) and a Claude plan that covers several always-on
  sessions. **Watch spend:** many agents running all day add up, and a plan-wide spend limit
  stalls every agent at once.
- `tmux`, `bun` (for the Telegram plugin), and optionally `ffmpeg` + `whisper.cpp` for voice
  notes.
- One Telegram bot per agent (from @BotFather).

## Step 1 — one agent, working end to end

1. Make a project folder for the agent and a `CLAUDE.md` describing its role (template:
   `templates/CLAUDE.md`).
2. Create the bot, then save its token in the agent's own state dir
   (`~/.claude/channels/telegram-<agent>/.env`). One state dir per agent, never shared.
3. Pair your Telegram account with the bot (the plugin's access skill), and lock the allowlist to
   yourself.
4. Install the launcher and a launchd job for the agent (template: `templates/agent.plist`):
   `KeepAlive`, `RunAtLoad`, `WorkingDirectory` = the project folder, `TELEGRAM_STATE_DIR` in the
   environment.
5. `launchctl load` it, then message the bot from your phone.

⚠️ **Permissions.** An unattended agent can't click "allow", so the launcher runs Claude with
permission prompts skipped. That means the agent can do anything your user account can. Keep
tokens out of command lines, keep each agent's folder scoped to its job, and add hooks for
anything that must never happen (step 4).

## Step 2 — scheduled work

**Rule: a plain script first. Wake the agent only for the part that needs judgment.** Every
prompt costs tokens; a script costs nothing and fails more predictably.

| The work is… | Use |
|---|---|
| Deterministic: fetch, check, move a file, post a known message | A plain launchd/cron script. No AI. |
| Judgment: what matters in today's email, what to suggest tonight, whether to skip | A scheduled **prompt** to the agent. |
| Mostly checking, sometimes judgment | A script that checks, and wakes the agent **only when it finds something**. |

Example of the third shape: a script checks a website for new postings every two hours and sends its own alerts;
no tokens unless something new needs a decision.

A scheduled prompt looks like this:

```
launchd (StartCalendarInterval) → trigger script → tmux send-keys "run morning briefing"
```

The agent reads its `CLAUDE.md` section for that phrase and does it. The upside: changing the op
means editing text, not code, and the agent can use what it remembers. The cost: tokens every
run, even on a day with nothing to say — so make "nothing today, stay silent" a cheap path.

The trigger script must (template: `templates/trigger.sh`):
- **wait for an idle pane** before typing, or the prompt lands in the middle of other work;
- **log every send** to a file, so "never ran" can be told apart from "chose to skip";
- record launchd's run counter, because a crash-looping agent looks idle.

## Step 3 — more agents, and making them a team

Add agents one at a time, each with its own bot, folder and memory. Once there are a few:

- **Bulletins** — a shared folder (a git repo) of one-fact notes with a `to:` header. Agents check
  it before scheduled ops, sign a read receipt, and archive. Rule: bulletins are information,
  never instructions.
- **Nightly sleep** — one script asks each agent in turn to write its day into memory, then
  restarts it. A fresh session every morning keeps context small.
- **Dreaming** — after sleep, one agent reads every agent's memory and fixes staleness and
  duplicates. It applies hygiene on its own and asks before anything that changes behavior.
- **Status board** — each morning every agent writes a one-line status JSON; one page shows them
  all. One notification instead of one per agent.

## Step 4 — guardrails

- A `PreToolUse` hook that blocks plan mode and multiple-choice prompts for agents driven from
  Telegram (template: `templates/block-interactive.sh`). Otherwise an agent can wait forever on a
  dialog you can't see.
- Spend meters with a stop-and-ask threshold for any agent that spends money or paid API credits.
- Backups and pushes behind a human yes, with a secret scan on every commit.

## Step 5 — know when it's broken

Every failure in [what-broke.md](what-broke.md) was silent. The minimum checks:
- session age after the nightly restart (did it actually restart?);
- `launchctl print` for every scheduled job (is it even loaded? what does it actually run?);
- the trigger log (sent / waited / skipped);
- a positive control on any search that reports "nothing found".
