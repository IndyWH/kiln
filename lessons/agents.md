# Agents

The helper agents, the watcher, and the rules hook's locks.

- Claude Code 2.1.323: agent files in `.claude/agents/` take `tools`, `model` (`opus`, `fable` or a full ID) and `effort`. Check one with `claude -p --agent reviewer --max-turns 1 "<question>" --output-format json`; `modelUsage` shows the model really used. `claude agents` lists running sessions, not agent files.
- Hook input carries `agent_id` and `agent_type` when a subagent, or a session started with `--agent`, calls a tool. The rules hook refuses changes from those. So never start the operator with `--agent`.
- A PreToolUse hook's "allow" does not override a deny rule in settings; deny wins.
- The single-operator lock follows the Claude window's process (the nearest parent named `claude`, with its start time against reused numbers), not the session, so `/clear` does not lock a window out of itself. State: `/var/log/kiln/operator.json`.
- Tests of the rules hook must point every path at a temp folder. The first lock tests wrote the real `/var/log/kiln/operator.json`.
- `kiln-watch --print` checks without writing or notifying. Notices from root go through `runuser -u indy` with the owner's `DBUS_SESSION_BUS_ADDRESS`. On its first run it marks current news as read.
- Agent icons on the bar, 13 Nov 2026: `kiln-agent-status` writes one file per agent in `/run/user/1000/kiln-agents/` (state, then a note). Claude Code hooks in `~/.claude/settings.json` feed it (copy in `config/claude/`), and `kiln-watch.service` does through `ExecStartPre` and `ExecStopPost`. `kiln-agent-status show` prints all four.
- Hook facts: `SubagentStart` and `SubagentStop` carry `agent_type`; `SubagentStop` has `last_assistant_message`, used for the reviewer's verdict. An interrupt sends no `Stop`, so the `idle_prompt` notification turns a stuck green back to blue. `permission_prompt` waits about 6 s; `PermissionRequest` is at once.
- Noctalia 5.4 plugins: a folder with `plugin.toml` and Luau in `~/.local/share/noctalia/plugins/` (not `~/.local/state`). Enable with `[plugins] enabled = [ "kiln/agents" ]`, add `[widget.kiln_agents] type = "kiln/agents:status"` and put `kiln_agents` in the bar's list. `noctalia plugins lint <folder>` checks it; `noctalia msg plugins list` shows it loaded. No file watching: `update()` with `noctalia.setUpdateInterval(1000)` polls. Glyphs are Tabler names, listed in `/usr/share/noctalia/assets/fonts/tabler.json`. Docs: docs.noctalia.dev/noctalia/v5.4.0/plugins/.
- `grim -g "X,Y WxH" file.png` screenshots part of the screen, to check what the bar shows.
- The watcher also checks the boot partition (/boot, 4 GB vfat), as every boot entry depends on it: attention below 25% free.

