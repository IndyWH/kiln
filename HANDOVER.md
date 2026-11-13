# Handover

## Next step

Kiln v2: wipe the Crucial P2 and install CachyOS. Follow docs/INSTALL.md, one part at a time:

1. Claude gets and checks the CachyOS ISO on the current system, and checks everything is on GitHub.
2. The owner makes the USB stick on another computer: the guard locks USB sticks on mlrig too.
3. The owner installs. Choose the disk by model, CT1000P2SSD8, never by size: the Samsung 870 QVO is also 931.5 GB.
4. First start: the owner installs Claude Code and clones `v2` to ~/Projects/kiln. Claude Code then installs the disk guard first, before the SATA disks go back in, then snapshots and `undo`, the rescue entry, the new rules, NVIDIA, the Hyprland look and a baseline.

## What carried over from v1

Copied from `stage1-guards` on 13 Nov 2026, to be checked on CachyOS before use:

- `guard/`, `tests/guard/`: the disk guard. Its paths and udev rule should work on Arch as they are.
- `sidekick/`: snapshots, `undo` and `restore`. `kiln_rules.py` asks before changes; rewrite it to inform instead.
- `config/hypr/`: Hyprland with Omarchy's look.
- `lessons/`: hardware, desktop, audio, network. The build, kernel and boot lessons were Gentoo's and stay on v1.
- `docs/HARDWARE.md`, `scripts/measure.sh`.

## Log

### 13 Nov 2026 — Claude Code, v2 started

- Owner's decisions: Kiln moves to CachyOS. Claude Code becomes the superuser, acting without asking and keeping the owner informed, as the owner hardly read the approval requests. The owner agreed to the safety model in docs/PHILOSOPHY.md. Start fresh on a new `v2` branch. The Crucial P2 can be wiped.
- v1's last commit pushed to `stage1-guards`. Wrote docs/INSTALL.md, after checking CachyOS's current installer: Limine is its default boot loader since January 2026, with snapshots in the boot menu.
- Wrote docs/DECISION-cachyos.md, docs/PHILOSOPHY.md and policy/CLAUDE.md, the new machine rules, as a draft until the safety pieces are installed.
