# Handover

## Next step

Kiln v2: wipe the Crucial P2 and install CachyOS. In order, one step at a time:

1. **Before the wipe.** Everything worth keeping must be on GitHub. Push the last v1 commit on `stage1-guards`. The owner says the drive can be wiped; their Firefox profile in ~/.config/mozilla goes with it.
2. **Install guide.** Claude Code writes docs/INSTALL.md: download CachyOS and check its checksum, make the USB stick, and the installer's choices: edition, Hyprland, btrfs, boot loader with snapshots in the boot menu.
3. **USB stick.** The owner makes it by hand: the disk guard rightly stops Claude writing to any disk but the P2.
4. **Install.** The owner installs. In the installer, choose the disk by its model, CT1000P2SSD8, never by size: the Samsung 870 QVO is also 931.5 GB. Unplugging the two SATA disks first makes a mistake impossible.
5. **First boot.** The owner installs Claude Code and clones the `v2` branch to ~/Projects/kiln. Claude Code then sets up, in order: the disk guard, automatic snapshots and `undo`, the rescue entry, the new policy (policy/CLAUDE.md), then NVIDIA, the Hyprland look, and a measured baseline.

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
- Wrote docs/DECISION-cachyos.md, docs/PHILOSOPHY.md and policy/CLAUDE.md, the new machine rules, as a draft until the safety pieces are installed.
