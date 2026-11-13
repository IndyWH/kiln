# Handover

## Next step

Part 5 of docs/INSTALL.md, first start, is done: guard, snapshots, rules hook, machine rules, agents, NVIDIA checks, the Omarchy look, and a measured baseline. Open:

1. Boot times: `scripts/measure.sh boot` after each of 5 restarts, when the owner can restart.

Known gap: snapshots 1 to 6 are older than the guard. Booting one from the menu starts without the guard.

## What carried over from v1

Copied from `stage1-guards` on 13 Nov 2026, to be checked on CachyOS before use:

- `guard/`, `tests/guard/`: the disk guard. Its paths and udev rule should work on Arch as they are.
- `sidekick/`: snapshots, `undo` and `restore`. `kiln_rules.py` asks before changes; rewrite it to inform instead.
- `config/hypr/`: Hyprland with Omarchy's look.
- `lessons/`: hardware, desktop, audio, network. The build, kernel and boot lessons were Gentoo's and stay on v1.
- `docs/HARDWARE.md`, `scripts/measure.sh`.
- `kiln-stories/`, `ai-bug-reports/`, and Claude's memory notes in `claude-memory/`.

## Log

### 13 Nov 2026 — Claude Code, log gap, login screen

- Owner's decision: CachyOS's login screen stays as it is. Claude's memory note about changing it removed.
- Log gap fixed in the rules hook: it asks the guard first, with the guard's own check, and does nothing for a call the guard will block. A change whose after step has not come within an hour is marked NOTRUN, its pending file removed, and `undo` skips it. 35 tests pass. Owner installed it; the first change after closed 12 leftover entries as NOTRUN, none wrongly.

### 13 Nov 2026 — Claude Code, updates, NVIDIA, the Omarchy look, baseline

- Owner asked for all of: push, updates, NVIDIA checks, the Omarchy look, the baseline. All done.
- Updates: flex, noctalia 5.5.0, openssh. The agent icons work on Noctalia 5.5.0.
- NVIDIA: driver 620.70.06 for both kernels, the 4090 idles, the desktop runs on the WX 3200. `python-pytorch-opt-cuda` (Arch's x86-64-v3 build) installed; `scripts/test-pytorch.py` passes; warm GPU speed level with v1. NVIDIA's sleep services stay off, as CachyOS intends. results/nvidia-cachyos-2026-11-13/.
- Omarchy look: Tokyo Night, solid windows, Omarchy's animations, in `~/.config/hypr/config/kiln.lua` (copy in config/hypr/kiln.lua). CachyOS's keys kept.
- Baseline against Ubuntu: CPU level or a little faster; audio and responsiveness under load clearly better. Performance mode gains nothing over balanced, so balanced stays. results/cachyos-2026-11-13/PREDICTIONS.md.
- gpu-unlock, which Ubuntu's run had: owner's decision, not for Kiln.

### 13 Nov 2026 — Claude Code, pull-down Claude and agent icons

- Owner installed the new rules hook. Checked live: a change from the operator ran; the same change from a helper was refused with the right message.
- Middle mouse opens and hides Claude Code in a pull-down window, carrying on the last conversation.
- Four boxed icons on the bar, one per agent: blue inactive, green working, red needs the owner. Each shows a note on hover; clicking opens the pull-down. Fed by Claude Code hooks and the watcher's service. See lessons/agents.md.

### 13 Nov 2026 — Claude Code, agents

- Owner asked for the agent design and approved it. Operator: Opus 5.5 high, the only one that changes things. Reviewer: Fable 5.2 high, read-only, before risky changes. Researcher: Opus 5.5 high, read-only. Watcher: `kiln-watch`, a script on a daily timer, installed and running; first report: all well. See docs/PHILOSOPHY.md, Agents.
- Rules hook: helpers cannot change anything; one Claude window at a time; the watcher's report in the session summary. 32 tests pass. Waiting for the owner to run `sudo sidekick/install.sh`, which also installs the new machine rules.
- `~/.claude/settings.json` now names `claude-opus-5-5` as the model.

### 13 Nov 2026 — Claude Code, CachyOS against Gentoo

- Owner asked: v1's five-program test on CachyOS, against v1's Gentoo results. Same files and work, outputs match v1's exactly. CachyOS is as fast or faster on all five: dav1d 1.0%, SQLite 5.6%, RawTherapee 7.8%, LightCraft 21% faster, darktable 0.5% slower. LightCraft's gain is mostly CachyOS's huge pages setting. results/cachyos-vs-gentoo/, lessons/speed.md.
- Installed for it, official packages: `rust`, `darktable`, `rawtherapee`, `meson`, `nasm`. Owner chose to keep them for now. The lab in /tmp/kiln-lab goes at restart.

### 13 Nov 2026 — Claude Code, weather

- Desktop weather asked for a location. Owner chose auto-locate; it works, but places the machine in central London. A town name in `[location] address` is the fix if that is wrong.

### 13 Nov 2026 — Claude Code, x86-64-v3 packages

- Owner's decision: no compiler benchmark. CachyOS's v3 packages whenever they exist; otherwise wait for CachyOS (owner chose this over rebuilding the 72 generic system packages after every update). From-source builds use x86-64-v3 instead of CachyOS's `native`. pacman already moves to v3 builds by itself; `kiln-v3` reports what is generic. See lessons/packages.md.

### 13 Nov 2026 — Claude Code, black background

- Owner asked for a black wallpaper. Noctalia's wallpaper is off, Hyprland's background is black, and Noctalia uses its built-in colour scheme instead of colours from the wallpaper.

### 13 Nov 2026 — Claude Code, window layout

- Owner asked for no gaps, and 1 window full, 2 halves, 3 thirds, 4 quarters. Done, and from 5 on, Claude's choice: 4 columns, extra windows stacked from the right, so 8 make a 4 by 2 grid. Corners squared; the 2-pixel active border kept.

### 13 Nov 2026 — Claude Code, screen and mouse

- Owner asked for the screen's full mode with VRR, and mouse copy and paste. The screen now runs 5120x1440 at 120 Hz with VRR always on. Mouse forward copies, back pastes; a terminal gets Ctrl+Shift. See lessons/desktop.md.

### 13 Nov 2026 — Claude Code, sidekick checked

- `sidekick/install.sh` is installed: every installed file matches the repo. A test change got before and after snapshots of root and home, and log lines. 24 sidekick tests pass. The guard's own tests are blocked for Claude, as designed; the owner runs them.
- Guard OK: only the P2 is writable. No failed services. Both kernels in the boot menu. NVIDIA 620.70.06 and Hyprland 0.57.2 working.
- Small gap: when the guard blocks a command, the rules hook has already taken a "before" snapshot and logged it, with no closing line, and leaves a file in /var/log/kiln/pending. `undo` skips such entries, so it is harmless.

### 13 Nov 2026 — Claude Code, first start on CachyOS

- CachyOS installed on the P2: btrfs, Limine, kernel 7.3.3 with the LTS 6.18 kernel as the rescue entry, snapper with limine-snapper-sync and snap-pac, NVIDIA 620.70.06 working, Hyprland 0.57.2. No failed services.
- All other disks were already plugged in at first start. Nothing on them was mounted or touched. The owner installed the guard; all four other disks are locked.
- Memory notes restored. The owner installed policy/sudoers-kiln as /etc/sudoers.d/10-kiln.
- Sidekick rewritten for v2: changes are snapshotted and logged, then run without asking; only `git push` asks. New hard limits in code: rescue packages, snapshot services and snapshots cannot be removed, and the owner's personal files (anything in /home/indy outside hidden folders, ~/Projects and Claude's space; the owner allowed ~/Projects the same day) cannot be deleted. A session-start summary and desktop notices for kernel and driver changes. CachyOS's limine-snapper-sync replaces v1's boot menu code, and `restore` now runs limine-snapper-restore. 24 tests pass.

### 13 Nov 2026 — Claude Code, v2 started

- Owner's decisions: Kiln moves to CachyOS. Claude Code becomes the superuser, acting without asking and keeping the owner informed, as the owner hardly read the approval requests. The owner agreed to the safety model in docs/PHILOSOPHY.md. Start fresh on a new `v2` branch. The Crucial P2 can be wiped.
- Owner asked for a Kiln story about the switch: kiln-stories/the-pots-were-already-fired.md. kiln-stories/ and ai-bug-reports/ copied from v1. Claude's v1 memory notes saved in claude-memory/, except the owner's Reddit post plan, kept out of this public repo. Correction: the 12.5% faster kernel compile was GCC rebuilt with LTO and profiles, not Clang as Claude first told the owner; Clang gained 5.4%.
- Part 1 done. ISO: cachyos-desktop-linux-260809.iso, 3,188,850,688 bytes, SHA-256 959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c. Checksum OK, and a good signature from CachyOS's key 882DCFE48E2051D48E2562ABF3B607488DB35A47, which matches wiki.cachyos.org. Both repo folders were fully pushed. Six Claude memory notes from v1 sessions were found only on the P2; see the owner's decision on keeping them.
- v1's last commit pushed to `stage1-guards`. Wrote docs/INSTALL.md, after checking CachyOS's current installer: Limine is its default boot loader since January 2026, with snapshots in the boot menu.
- Wrote docs/DECISION-cachyos.md, docs/PHILOSOPHY.md and policy/CLAUDE.md, the new machine rules, as a draft until the safety pieces are installed.
