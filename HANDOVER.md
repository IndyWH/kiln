# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1 planning. No install work has started.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy is still on it, but the owner has copied what he needs, so the drive is free to wipe (2 Nov 2026).
- Work can start now.
- Owner decisions: nine decided on 23 Oct 2026. Decision 10, the lessons file layout, waits for the owner. See the Answer column in docs/STAGE1_SPEC.md.
- Screen: mini DisplayPort from the WX 3200, live images included. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.

## Next step

Survey Omarchy, looking only. Claude Code on Omarchy reads how the drive is unlocked at boot, what is mounted, which measuring tools are installed, and what Hyprland needs for the WX 3200 to drive the screen. It changes nothing and writes one report to the USB stick. That report decides how the passphrase wait comes out of Omarchy's boot time.

Baseline plan, agreed 23 Oct 2026:

- One measurement script in the repo, run the same way on Omarchy, Kiln and Ubuntu, with the same fixed workload on each.
- Boot time over 5 boots per system, median reported. Firmware reported separately.
- The passphrase typing time comes out of Omarchy's numbers. The cost of decrypting the disk stays in, and the report says so.
- Results travel from Omarchy to the repo on a USB stick. No GitHub sign-in on Omarchy.
- Ubuntu 26.10 is measured too, as a second reference. Its disk numbers are left out.
- Measure with the WX 3200 driving the screen (fitted on 24 Oct 2026). The cooling-off period ended early on 2 Nov 2026.

## Log

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
