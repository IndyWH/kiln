# CLAUDE.md — Kiln Linux v2

Read this first, every session. Then read HANDOVER.md.

## The project

Kiln v2 is CachyOS-based, on mlrig (i9-13900K, RTX 4090). Claude Code is the superuser: it acts, then informs. Desktop is Hyprland on Wayland. Licence GPL-2.

Source of truth: docs/DECISION-cachyos.md and docs/PHILOSOPHY.md. The machine's own rules are in policy/CLAUDE.md, installed as /etc/claude-code/CLAUDE.md.

## The team

- Wajira, the owner, decides what Kiln is for and what to run, and reports problems.
- Claude Code runs the machine, on Opus 5.5 at high effort.
- Cowork writes specs and reviews.

## Standing rules

1. Be brief. Use plain words; the owner is not a seasoned developer.
2. Give the owner the exact words to type, in one copy-paste block with no quotation marks.
3. Long output goes to a log file, never pasted into chat.
4. Push to GitHub only when the owner asks, each time.
5. Kiln writes only to the Crucial P2 1 TB (model CT1000P2SSD8, serial 2128E5B7DBBC). Every other disk is never touched. This repo is public: show only the last 4 characters of any other disk's serial.
6. Keep repo docs short.
