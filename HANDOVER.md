# Handover

## Next step

Kiln v2: wipe the Crucial P2 and install CachyOS. Follow docs/INSTALL.md, one part at a time:

1. Claude gets and checks the CachyOS ISO on the current system, and checks everything is on GitHub.
2. The owner makes the USB stick on another computer: the guard locks USB sticks on mlrig too.
3. The owner installs. Choose the disk by model, CT1000P2SSD8, never by size: the Samsung 870 QVO is also 931.5 GB.
4. First start: the owner installs Claude Code and clones `v2` to ~/Projects/kiln. Claude Code then restores its memory notes from claude-memory/ (see its README), installs the disk guard first, before the SATA disks go back in, then snapshots and `undo`, the rescue entry, the new rules, NVIDIA, the Hyprland look and a baseline.

## What carried over from v1

Copied from `stage1-guards` on 13 Nov 2026, to be checked on CachyOS before use:

- `guard/`, `tests/guard/`: the disk guard. Its paths and udev rule should work on Arch as they are.
- `sidekick/`: snapshots, `undo` and `restore`. `kiln_rules.py` asks before changes; rewrite it to inform instead.
- `config/hypr/`: Hyprland with Omarchy's look.
- `lessons/`: hardware, desktop, audio, network. The build, kernel and boot lessons were Gentoo's and stay on v1.
- `docs/HARDWARE.md`, `scripts/measure.sh`.
- `kiln-stories/`, `ai-bug-reports/`, and Claude's memory notes in `claude-memory/`.

## Log

### 13 Nov 2026 — Claude Code, v2 started

- Owner's decisions: Kiln moves to CachyOS. Claude Code becomes the superuser, acting without asking and keeping the owner informed, as the owner hardly read the approval requests. The owner agreed to the safety model in docs/PHILOSOPHY.md. Start fresh on a new `v2` branch. The Crucial P2 can be wiped.
- Owner asked for a Kiln story about the switch: kiln-stories/the-pots-were-already-fired.md. kiln-stories/ and ai-bug-reports/ copied from v1. Claude's v1 memory notes saved in claude-memory/, except the owner's Reddit post plan, kept out of this public repo. Correction: the 12.5% faster kernel compile was GCC rebuilt with LTO and profiles, not Clang as Claude first told the owner; Clang gained 5.4%.
- Part 1 done. ISO: cachyos-desktop-linux-260809.iso, 3,188,850,688 bytes, SHA-256 959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c. Checksum OK, and a good signature from CachyOS's key 882DCFE48E2051D48E2562ABF3B607488DB35A47, which matches wiki.cachyos.org. Both repo folders were fully pushed. Six Claude memory notes from v1 sessions were found only on the P2; see the owner's decision on keeping them.
- v1's last commit pushed to `stage1-guards`. Wrote docs/INSTALL.md, after checking CachyOS's current installer: Limine is its default boot loader since January 2026, with snapshots in the boot menu.
- Wrote docs/DECISION-cachyos.md, docs/PHILOSOPHY.md and policy/CLAUDE.md, the new machine rules, as a draft until the safety pieces are installed.
