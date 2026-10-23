# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1 planning. No install work has started.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy is on it now, in its cooling-off period.
- Work starts in about a month from 23 Oct 2026.
- Owner decisions: all nine decided on 23 Oct 2026. See the Answer column in docs/STAGE1_SPEC.md.

## Next step

Next session: plan the Omarchy baseline measurement. It must happen before the Crucial drive is wiped.

Points for that plan:

- Omarchy on the Crucial drive is LUKS-encrypted. Its boot time includes typing the passphrase, and Kiln will have no encryption (decision 3). The plan must take the unlock time out of Omarchy's numbers, or the comparison is unfair.
- The WX 3200 is fitted on 26 Oct 2026. Measure the baseline after that, with the WX 3200 driving the screen. Omarchy stays on the Crucial drive for at least three more weeks from 23 Oct 2026.

## Log

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
