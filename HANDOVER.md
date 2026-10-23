# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1 planning. No install work has started.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy is on it now, in its cooling-off period.
- Work starts in about a month from 23 Oct 2026.
- Owner decisions: all nine decided on 23 Oct 2026. See the Answer column in docs/STAGE1_SPEC.md.

## Next step

Survey Omarchy, looking only. Claude Code on Omarchy reads how the drive is unlocked at boot, what is mounted, which measuring tools are installed, and what Hyprland needs for the WX 3200 to drive the screen. It changes nothing and writes one report to the USB stick. That report decides how the passphrase wait comes out of Omarchy's boot time.

Baseline plan, agreed 23 Oct 2026:

- One measurement script in the repo, run the same way on Omarchy, Kiln and Ubuntu, with the same fixed workload on each.
- Boot time over 5 boots per system, median reported. Firmware reported separately.
- The passphrase typing time comes out of Omarchy's numbers. The cost of decrypting the disk stays in, and the report says so.
- Results travel from Omarchy to the repo on a USB stick. No GitHub sign-in on Omarchy.
- Ubuntu 26.10 is measured too, as a second reference. Its disk numbers are left out.
- Measure after the WX 3200 is fitted on 26 Oct 2026, with it driving the screen. Omarchy stays on the Crucial drive for at least three weeks from 23 Oct 2026.

## Log

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
