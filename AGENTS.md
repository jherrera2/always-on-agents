# AGENTS.md — set up an always-on agent fleet for your human

> For AI coding agents (Claude Code, Codex, etc.) helping a person follow
> [docs/setup.md](docs/setup.md). Humans: read setup.md instead.

You are helping a person run persistent Claude Code agents, each reachable over its own
Telegram bot. Work **one step at a time**, verify each step before moving on, and stop at every
🧑 checkpoint — those need the human.

## Ground rules

- **Never print, log, commit or echo a bot token or API key.** Write secrets only to the agent's
  own `.env` with mode `600`. Don't put tokens on a command line (they show up in `ps`).
- **Ask before** installing or loading any launchd/systemd job, editing shell config, or
  turning off permission prompts.
- **One agent first.** Don't create a second agent until the first passes every check in Step 1.
- **Script first, AI second.** If a scheduled task needs no judgment, make it a plain script.
  Only schedule a prompt when the agent has to decide something (see setup.md, Step 2).
- macOS uses launchd; Linux uses systemd. Detect which, and adapt — don't guess.

## Step 0 — check prerequisites

Confirm and report versions for: `claude`, `tmux`, `bun`, `git`. Optional: `ffmpeg`,
`whisper-cli` (voice notes). Report anything missing and how to install it; install only after
the human says yes.

## Step 1 — the first agent

1. 🧑 Ask the human for: the agent's name, its job in one sentence, and its project folder.
2. Create the folder and a `CLAUDE.md` from `templates/CLAUDE.md`, filled in with that job.
3. 🧑 The human creates a bot with @BotFather and pastes the token **into the `.env` file
   themselves**, or tells you a path to read it from. Do not ask them to paste it into chat.
4. Create the state dir `~/.claude/channels/telegram-<agent>/` (mode `700`), `.env` mode `600`.
5. 🧑 Explain the permissions trade-off: an unattended agent runs with permission prompts
   skipped and can do anything the user account can. Get an explicit yes.
6. Install the launcher (see Credit in setup.md) and write the launchd plist from
   `templates/agent.plist`. 🧑 Show the plist, then load it on their yes.
7. **First launch in a new folder shows a "trust this folder?" dialog.** Attach to the agent's own
   tmux pane (`tmux -L <agent> attach -t claude-<agent>`), answer it, detach. Until then the agent
   looks running but does nothing.
8. 🧑 The human messages the bot and pairs, then locks the allowlist to themselves.
9. Add the agent to the human's roster file (name, bot, folder, launchd label), so the list of
   agents always matches what is actually loaded.

**Verify before going on (all must pass):**
- the job is loaded (`launchctl print gui/$(id -u)/<label>`) and `state = running`;
- exactly one Telegram poller process has this agent's `TELEGRAM_STATE_DIR` in its environment;
- the human sends a message and gets a reply;
- restart it (`launchctl kickstart -k …`) and the reply still works;
- from the second agent on: **every agent's bot token is different.** Two agents sharing a token
  both poll the same bot and messages vanish.

## Step 2 — scheduled work

For each recurring task the human wants, decide with them:
- **No judgment needed** → a plain script on a schedule. Done; no agent involved.
- **Judgment needed** → a trigger script (`templates/trigger.sh`) that waits for an idle pane,
  logs every send, records launchd's `runs` counter, then types the prompt. Add a matching
  section to the agent's `CLAUDE.md` that says exactly what to do when it receives that phrase,
  including when to stay silent.

**Verify:** test the trigger against a scratch tmux session first (never fire the live agent to
test), then check the log shows `SENT`.

## Step 3 — more agents

Repeat Step 1 per agent: its own bot, its own state dir, its own folder. Then, only if the human
wants agents to share information:
- a bulletins folder (a git repo) with the format in `templates/bulletin.md`;
- a line in each `CLAUDE.md` telling the agent to check bulletins before scheduled work;
- optional nightly sleep (consolidate memory → restart) and a morning status file per agent.

## Step 4 — guardrails

- Install the `PreToolUse` hook (`templates/block-interactive.sh`) so agents driven from
  Telegram can't open plan-mode or multiple-choice dialogs the human can't answer.
- For any agent that spends money: a spend ledger and a stop-and-ask threshold, agreed with the
  human.

## Known gotchas

- **Use the agent's own tmux socket** (`tmux -L <agent> …`) in every command. Without `-L` you
  type into a different tmux server and the prompt disappears with no error.
- **Never run the `claude` CLI from inside an agent's shell** (e.g. `claude mcp list`). It starts
  the Telegram channel against the same bot and kills the live agent's poller when it exits. Read
  config files instead.
- **After `claude update`,** check the Telegram plugin still runs one poller per agent; if the
  launcher setup patches the plugin, re-apply the patch and restart **every** agent, enumerated
  from `launchctl list`, not from a hard-coded list.
- **List agents from the system** (`launchctl list | grep <your label prefix>`), not from a
  folder listing or a document — plist files can outlive a removed agent.

## Step 5 — hand-off

Give the human a short summary: each agent, its bot, its schedule, where its logs are, and how
to stop it (`launchctl bootout …`). Point them at [docs/what-broke.md](docs/what-broke.md) for
the silent failures to watch for.
