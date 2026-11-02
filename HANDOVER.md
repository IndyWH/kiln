# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1, step 3 (guards first). No install work has started. The guard is built and proved on fake disks, but it is not installed. No real disk is locked yet.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy is still on it, but the owner has copied what he needs, so the drive is free to wipe (2 Nov 2026).
- Work can start now.
- Owner decisions: all ten decided. See the Answer column in docs/STAGE1_SPEC.md.
- Baseline: Ubuntu 26.10 on mlrig only. Omarchy is skipped.
- Screen: mini DisplayPort from the WX 3200, live images included. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.

## Next step

Finish spec step 3, once the owner approves: run `sudo guard/install.sh`, restart Claude Code, then run the real-disk checks. No disk work before that.

After any restart of the live system, the guard is gone. Clone the repo and run `sudo guard/install.sh` again before any disk work. The work is on branch stage1-guards until the owner merges it, so use `git clone -b stage1-guards`.

Baseline still open: 4 more Ubuntu boots. The owner runs `scripts/measure.sh boot` whenever he next boots Ubuntu, over time. This does not hold up Kiln.

## Log

### 2 Nov 2026 — Claude Code, disk guard built and lessons file started

- Live start done: Claude Code runs on the LiveGUI image on mlrig. The repo copy of step 3 matches the Claude Doc.
- Added guard/: a kernel read-only lock, a udev rule for new disks, and a Claude Code hook. Finds the Crucial by serial. Any doubt means locked or blocked.
- Proved on fake disks in memory: results/guard-proof-2026-11-02/, with summary.txt as the short result. Real disks' write counts and lock flags did not change.
- Not yet done: install on the real system, and the real-disk checks. That is the rest of step 3.
- Limits: root can undo the lock. Raw drive commands skip the lock, so only the hook stops them, and the hook reads command text. This protects against mistakes, not deliberate attempts to get around it. The guard must be installed and proved again on the installed system, which uses systemd, not OpenRC.
- Added lessons/, the layout from decision 10.
- Other disks' serials are masked to the last 4 in the repo, by owner's decision.
- Cowork: the spec's step 10 adds hooks for the four rules. The disk guard hook already exists, so those need to sit alongside it.

### 2 Nov 2026 — Claude Code, baseline run and kickoff checks

- Ubuntu main run done, in results/ubuntu-26.10-2026-11-02/: smallest clean audio buffer 256 samples, wake-up delay 99.9% at 0.99 ms, sysbench 39,181 and 7-Zip 210,923 on 32 threads.
- Boot: 1 of 5 saved. The owner decided the rest can wait, because Kiln is the priority.
- For the comparison: use the 99.9% wake-up figure, in responsiveness.csv. The median is mostly the kernel's fixed 0.05 ms timer slack.
- Kickoff check: Gentoo offers ready-built packages at x86-64-v3 (23.0/x86-64-v3, updated 2 Nov 2026). The i9-13900K supports v3 but not v4, so v3 is the right level.
- Live image: livegui-amd64-20260913T163055Z.iso, the newest offered. Downloaded to the Ventoy drive with the owner's approval. Checksum matches, and the checksum file is signed by Gentoo's weekly release key.
- Added docs/LIVE_START.md, so the owner can copy the steps in Firefox on the live desktop.

### 2 Nov 2026 — Claude Code, measurement script

- Added scripts/measure.sh. Modes: `run`, `boot`, `new`. `--short` is a quick test, kept out of git.
- Results go to results/<os>-<date>/, with summary.txt as the short result.
- run-bench.sh was not found on any mounted drive. The owner chose fresh settings: sysbench CPU test, 30 seconds, and 7-Zip benchmark at 32 MB, each on 1 and on all threads, median of 3. Cowork: the spec still calls it the existing script and warns about its test files, so it needs updating, Claude Doc first.
- Short test passed. Audio dropouts appeared at buffer 64 under compile load, but not at any size down to 32 with no load. Freezing the test playback for 1 second was counted as dropouts. These were short runs, not results.
- Kiln needs a login screen that reaches graphical.target and the same audio output, for a fair comparison.

### 2 Nov 2026 — Cowork, owner answers

- Baseline: skip Omarchy. Compare Kiln with Ubuntu 26.10 on mlrig only.
- Decision 10, the lessons file layout, accepted.
- Repo docs stay concise. Added as a standing rule in CLAUDE.md.

### 2 Nov 2026 — Cowork, spec fixes

- Owner: Omarchy's contents are copied, so the Crucial drive is free to wipe. The cooling-off period is over.
- Owner decided: the screen uses mini DisplayPort from the WX 3200, not HDMI. The WX 3200 has only mini DisplayPort sockets. HDMI into the RTX 4090 is the fallback for a black screen on a live image.
- Fixed the WX 3200 date: fitted on 24 Oct 2026, not 26 Oct.
- Added the lessons file to the spec, as a new section and as decision 10, waiting for the owner.
- Changed in the Claude Doc first, then in docs/STAGE1_SPEC.md.

### 23 Oct 2026 — Cowork, owner idea: lessons file

- Owner's idea: the first time Claude is active during the install, it creates a lessons-learnt file that stays in the installed system. It records findings and pitfalls with the hardware and software, in logical sections, so Claude can later read only the section it needs when building or troubleshooting.
- Cowork's suggestion, for the owner to confirm: a short index file (the system's CLAUDE.md) that points to one file per section, such as hardware, build settings and failed packages, kernel, boot, desktop, audio and network. Claude Code reads CLAUDE.md in full every session, so it must stay short. A copy goes into the repo, so the install can be repeated.
- To do next Cowork session: add it to the Stage 1 spec, Claude Doc first, then the repo copy.

### 23 Oct 2026 — Cowork, baseline plan

- The owner chose: results on a USB stick, 5 boots per system with the median, and Ubuntu measured as a second reference.
- First step is a look-only survey of Omarchy. The fair way to remove the passphrase wait depends on whether Omarchy unlocks the drive inside systemd, so it is decided after the survey.
- In this session the mlrig file tools worked, and Cowork wrote to the repo directly.

### 23 Oct 2026 — Cowork, owner decisions

- The owner decided all nine Stage 1 decisions. Recorded in the Claude Doc and in docs/STAGE1_SPEC.md.
- Decision 1 gained one point: Stage 1 boots Gentoo's LiveGUI image, so the Claude sign-in happens in Firefox on mlrig itself. Live start step 2 updated to match.
- Decision 6 was changed by the owner: on the first boot after install, a pop-up offers to install the Claude desktop app, so Cowork can run on Kiln. Kiln needs its own recipe for it. Check at kickoff that it works and that Anthropic's terms allow it.
- In this Cowork session the folder was connected, but the file tools for mlrig never loaded. Files went across as one archive instead. Try a fresh Cowork session next time.

### 23 Oct 2026 — Cowork, repo set-up

- Created README.md, LICENSE (GPL-2), CLAUDE.md, HANDOVER.md.
- Copied the two Claude Docs into docs/VISION.md and docs/STAGE1_SPEC.md.
- Added an Answer column to the owner decisions table in docs/STAGE1_SPEC.md.
- The owner created the public GitHub repo IndyWH/kiln and pushed the first commit (2707f87).
