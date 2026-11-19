# Templates

Small, original starting points. Replace every `CAPITALISED` placeholder.

| File | What it is |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Skeleton for one agent's role, rules and scheduled prompts. |
| [`agent.plist`](agent.plist) | launchd job that keeps one agent running. |
| [`scheduled-op.plist`](scheduled-op.plist) | launchd job that sends a scheduled prompt (weekdays 8:00). |
| [`trigger.sh`](trigger.sh) | Types a prompt into an agent: waits for idle, logs every send, warns on restart loops. Test it against a scratch tmux session, never a live agent. |
| [`block-interactive.sh`](block-interactive.sh) | PreToolUse hook: no terminal dialogs for Telegram-driven agents. |
| [`bulletin.md`](bulletin.md) | One-fact note between agents, with the read/archive protocol. |
| [`status.json`](status.json) | Morning status line each agent writes for the board. |

The launcher that starts `claude` in a per-agent tmux server isn't here; see the Credit
section in [docs/setup.md](../docs/setup.md).
