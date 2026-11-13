# Handover

## Next step

Part 5 of docs/INSTALL.md, first start. Done: memory notes, disk guard, passwordless `sudo`. Next:

1. The owner runs `sudo sidekick/install.sh`: the rules hook (snapshot and log before every change, then act without asking), `undo`, `restore`, home snapshots, and policy/CLAUDE.md as the machine rules. Then restart Claude Code and check a test change is snapshotted and logged.
2. Then NVIDIA checks, the Hyprland look, and a measured baseline.

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

### 13 Nov 2026 — Claude Code, first start on CachyOS

- CachyOS installed on the P2: btrfs, Limine, kernel 7.3.3 with the LTS 6.18 kernel as the rescue entry, snapper with limine-snapper-sync and snap-pac, NVIDIA 620.70.06 working, Hyprland 0.57.2. No failed services.
- All other disks were already plugged in at first start. Nothing on them was mounted or touched. The owner installed the guard; all four other disks are locked.
- Memory notes restored. The owner installed policy/sudoers-kiln as /etc/sudoers.d/10-kiln.
- Sidekick rewritten for v2: changes are snapshotted and logged, then run without asking; only `git push` asks. New hard limits in code: rescue packages, snapshot services and snapshots cannot be removed, and the owner's personal files (anything in /home/indy outside hidden folders, this repo and Claude's space) cannot be deleted. A session-start summary and desktop notices for kernel and driver changes. CachyOS's limine-snapper-sync replaces v1's boot menu code, and `restore` now runs limine-snapper-restore. 24 tests pass.

### 13 Nov 2026 — Claude Code, v2 started

- Owner's decisions: Kiln moves to CachyOS. Claude Code becomes the superuser, acting without asking and keeping the owner informed, as the owner hardly read the approval requests. The owner agreed to the safety model in docs/PHILOSOPHY.md. Start fresh on a new `v2` branch. The Crucial P2 can be wiped.
- Owner asked for a Kiln story about the switch: kiln-stories/the-pots-were-already-fired.md. kiln-stories/ and ai-bug-reports/ copied from v1. Claude's v1 memory notes saved in claude-memory/, except the owner's Reddit post plan, kept out of this public repo. Correction: the 12.5% faster kernel compile was GCC rebuilt with LTO and profiles, not Clang as Claude first told the owner; Clang gained 5.4%.
- Part 1 done. ISO: cachyos-desktop-linux-260809.iso, 3,188,850,688 bytes, SHA-256 959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c. Checksum OK, and a good signature from CachyOS's key 882DCFE48E2051D48E2562ABF3B607488DB35A47, which matches wiki.cachyos.org. Both repo folders were fully pushed. Six Claude memory notes from v1 sessions were found only on the P2; see the owner's decision on keeping them.
- v1's last commit pushed to `stage1-guards`. Wrote docs/INSTALL.md, after checking CachyOS's current installer: Limine is its default boot loader since January 2026, with snapshots in the boot menu.
- Wrote docs/DECISION-cachyos.md, docs/PHILOSOPHY.md and policy/CLAUDE.md, the new machine rules, as a draft until the safety pieces are installed.
