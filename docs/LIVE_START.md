# Live start

Spec step 2. Open this page in Firefox on the live desktop, so you can copy from it.

## 1. Before you start

- The screen is on mini DisplayPort from the WX 3200. If the live image shows a black screen, use HDMI into the RTX 4090 for this session.
- Connect by the wired network. It should come up by itself.

## 2. In a terminal on the live desktop

Paste this as one block. It installs Claude Code and starts it. Sign in through Firefox when it asks.

```bash
curl -fsSL https://claude.ai/install.sh | bash
export PATH=$HOME/.local/bin:$PATH
mkdir -p ~/Projects
cd ~/Projects
claude
```

Use Opus 5.5 at high effort. Check with `/model`.

## 3. First prompt for Claude Code

New session. Paste this:

```text
You are running on the Gentoo LiveGUI image on mlrig, for Kiln Linux Stage 1.
1. Clone https://github.com/IndyWH/kiln.git into ~/Projects/kiln. Install git first if it is missing.
2. Read CLAUDE.md, HANDOVER.md and docs/STAGE1_SPEC.md. Follow the standing rules.
3. This live system runs from memory, so anything not saved is lost on restart. Tell me how you will keep the work safe.
4. Your task is spec step 3, Guards first, and starting the lessons file.
5. The only disk you may ever write to is the Crucial P2, serial 2128E5B7DBBC. Find it by serial, never by device name.
6. The guard must be proved without any real write reaching another disk.
Plan first. Do not touch any disk. Then stop and wait for my approval.
```
