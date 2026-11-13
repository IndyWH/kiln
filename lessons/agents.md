# Agents

The helper agents, the watcher, and the rules hook's locks.

- Claude Code 2.1.323: agent files in `.claude/agents/` take `tools`, `model` (`opus`, `fable` or a full ID) and `effort`. Check one with `claude -p --agent reviewer --max-turns 1 "<question>" --output-format json`; `modelUsage` shows the model really used. `claude agents` lists running sessions, not agent files.
- Hook input carries `agent_id` and `agent_type` when a subagent, or a session started with `--agent`, calls a tool. The rules hook refuses changes from those. So never start the operator with `--agent`.
- A PreToolUse hook's "allow" does not override a deny rule in settings; deny wins.
- The single-operator lock follows the Claude window's process (the nearest parent named `claude`, with its start time against reused numbers), not the session, so `/clear` does not lock a window out of itself. State: `/var/log/kiln/operator.json`.
- Tests of the rules hook must point every path at a temp folder. The first lock tests wrote the real `/var/log/kiln/operator.json`.
- `kiln-watch --print` checks without writing or notifying. Notices from root go through `runuser -u indy` with the owner's `DBUS_SESSION_BUS_ADDRESS`. On its first run it marks current news as read.
