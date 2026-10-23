# CLAUDE.md — Kiln Linux

Read this first, every session. Then read HANDOVER.md.

## The project

Kiln Linux is a public, Gentoo-based distribution. Claude is a built-in sidekick that analyses the hardware, builds every program for that exact CPU, tunes the system, and looks after it when the user chats with Claude Code in the terminal. Desktop is Hyprland on Wayland. Licence GPL-2.

Source of truth:

- Vision: docs/VISION.md (Claude Doc: https://claude.ai/artifact/LKdCA8eLpUT27X5B6A9Ds1)
- Stage 1 spec: docs/STAGE1_SPEC.md (Claude Doc: https://claude.ai/artifact/HWbM9gx3AcJzjfq5tVZEae)

If the repo copy and the Claude Doc disagree, the Claude Doc wins. Tell the owner, then bring the repo copy into line.

## The team

- Wajira, the owner, decides and approves.
- Cowork writes specs and reviews.
- Claude Code implements, on Opus 5.5 at high effort.

## Standing rules

1. One document, tasks in execution order. One consolidated copy-paste block, no quotation marks.
2. One step at a time. Do not move on until the owner has reported back.
3. Long output goes to a log file in the repo, never pasted into chat.
4. Cowork never runs git status or any git command that writes the index. Cowork uses git log and git show only.
5. With every prompt for Claude Code, say whether it is a new session, /clear first, or the current session, and which model and effort. Give the owner the exact words to type whenever Claude Code needs an answer.
6. Be brief. The owner is not a seasoned developer, so use plain words.
7. GitHub pushes are done by the owner's own hand.

## Stage 1 boundary

On mlrig, Stage 1 may write only to the Crucial P2 1 TB drive (serial 2128E5B7DBBC). Every other disk is never touched.
