# HANDOVER — Kiln Linux

The coordination log between the owner, Cowork and Claude Code. Newest entry at the top.

## Current state

- Stage: Stage 1. Steps 3 to 7 are complete. Step 8 is built. The mlrig kernel boots, with 3 checks failed. The rescue kernel has not been checked, and can wait, by owner's decision. Step 9 is done: Kiln boots to the desktop, with network and sound working. Claude Code runs on Kiln, signed in. Step 10: part 1 of 4 is done. Part 2 is installed and mostly proved, but `undo` has not yet run for real. Stopped here by owner's decision.
- Priority, by owner's decision: Kiln boots to the desktop, then work moves to Claude Code on Kiln, to end the restarts into the live image.
- Target: mlrig, Crucial P2 1 TB drive only. Omarchy has been wiped. Two kernels, the boot loader, the guard and the desktop are on it, with snapshot 5 taken (3 Nov 2026). Kiln now runs from this drive.
- Owner decisions: all ten decided. See the Answer column in docs/STAGE1_SPEC.md.
- Owner wants Chromium compiled for mlrig, after step 9 and once the step 11 settings are on. Not started.
- Owner wants the Claude desktop app at some point. Not part of step 10. Not started.
- Baseline: Ubuntu 26.10 on mlrig only. Omarchy is skipped.
- Screen: mini DisplayPort from the WX 3200, live images included. HDMI into the RTX 4090 is the fallback if a live image shows a black screen.

## Next step

Finish part 2: the real `undo` test. Do not start part 3 until it passes. The owner opens a terminal with Super+Return and runs the line below, pressing `y` when asked. It should ask twice, for `kiln-test-refused.txt` and then `kiln-test.txt`. The third `undo` should say there is nothing to undo, and neither file should be left in ~/.config. The install also updates the installed hook, which is older than the repo copy. Claude Code does not need a restart for this update.

`cd ~/Projects/kiln && sudo sidekick/install.sh && undo; undo; undo; ls ~/.config`

Keep it as one line, because `undo` reads its answer from the terminal, and pasted lines would count as answers.

Step 10, in four parts, reporting back after each:

1. Sidekick key and rules file. Done.
2. Hooks for rules 1 and 2, with the change log and `undo`. Hooks go in the protected folder, installed by the owner's hand. `undo` restores only `~/.config` in the home folder, by owner's decision. Installed. Waiting for the `undo` test.
3. Past snapshots in the boot menu.
4. Tests: break the desktop and recover with `undo`, and boot the rescue kernel and a past snapshot. A fix for the guard's false alarms, installed by the owner's hand.

To reach Kiln, the owner presses F8, chooses the Crucial, logs in as `indy`, and presses Super+Space.

Open, and not holding this up:

- The rescue kernel: boot it from the 3-second menu and run `kiln-first-boot-check`, as in docs/FIRST_BOOT.md. It writes to its own folder in /var/log/kiln-first-boot/ on the Crucial. Then copy the results as for the mlrig kernel, with IDs removed.
- The first-boot guard test always shows 1 failure on Kiln, because it counts the Crucial's own writes. Fixing the test goes through the owner's hand.
- Omarchy's configs are not ported. See the log.

The Crucial shows in F8 as `UEFI OS`, because the `Kiln` entry has gone. If Kiln does not start, Ubuntu is untouched and first, and it can be fixed from the live image.

To re-test the guard after any change, the owner runs `sudo tests/guard/fake_disks.sh --installed-rule` in a terminal, because the hook blocks Claude from running it.

After any restart of the live system, the guard is gone. Clone the repo and run `sudo guard/install.sh` again before any disk work, and restart Claude Code so it loads the hook. Work is merged to main before each restart.

Baseline still open: 4 more Ubuntu boots. The owner runs `scripts/measure.sh boot` whenever he next boots Ubuntu, over time. This does not hold up Kiln.

## Log

### 3 Nov 2026 — Claude Code, step 10 part 2, not yet proven

- Added sidekick/: the rules hook, `undo`, its settings and an install script. The owner installed it by hand. The hook and rules file sit in protected places. Log: /var/log/kiln/changes.log. Home snapshots are on, and old snapshots are now cleaned up, as that timer was off.
- Proved live: a change with no explanation is refused. The owner sees the explanation in the approval question. Saying No stops the change, and the log shows it asked but not done. Each change gets before and after snapshots, which show exactly the files changed.
- Not proved: `undo` on real snapshots. Its tests use a stand-in for `snapper`. 18 tests pass.
- Two fixes are in the repo but not yet installed: `undo` skips a false alarm that changed nothing, and the guard's status check no longer asks.
- Known limits: the hook reads command text, so it asks about some commands that only read, such as ones using `$(( ))`. Refused changes leave an unused snapshot and a small file in /var/log/kiln/pending. Claude could still edit the log, as it is not a protected file. Home snapshots hold copies of the saved GitHub token, on this machine only.
- Two test files are in ~/.config until the `undo` test removes them.
- Cowork: the spec says "a snapshot before every change". Commits and edits inside the repo do not get one, as the repo is not the system, and `git push` is asked about but has no snapshot.

### 3 Nov 2026 — Claude Code, step 10 part 1

- Owner's decision on decision 5: the sidekick key is Super+Space. It opens Claude Code in ~/Projects/kiln, then hides and shows it, and the chat keeps running while hidden. Script: config/usr/local/bin/kiln-sidekick.
- Tested by running the script three times: the window opened, hid and came back, with Claude Code still running. The owner then pressed the real key and it works.
- Rules file: config/claude/CLAUDE.md, copied to ~/.claude/CLAUDE.md for now. A fresh session named all four rules from it. It moves to the protected folder in part 2.
- Snapshot 6 is the working desktop, taken before this part. It does not cover the home folder.
- Cowork: the spec and its Claude Doc still say pushes are by the owner's own hand. Please update them to the new rule 7.
- Cowork: decision 6 says a pop-up on first boot offers the Claude desktop app. There is no record of it being built, or of Anthropic's terms being checked. The owner wants the app at some point, so the spec needs a new place for it.

### 3 Nov 2026 — Claude Code, first desktop boot

- Kiln boots to the desktop on the mlrig kernel. Hyprland runs on the WX 3200, with the Philips at 5120x1440, 120 Hz. No failed services.
- Wired network works, so matching `en*` fixed it.
- Sound works through the Philips, and the owner heard the test tone. It defaulted to USB S/PDIF because nothing had been chosen. The owner chose the Philips, the same output as the Ubuntu baseline. See lessons/audio.md.
- Keyboard: the owner's FIELD75 uses US, so Hyprland is now `us`. The login screen and text consoles were already US.
- The hook blocked two harmless commands on Kiln, as it read text in them as paths. For the review in step 10.
- Not tested: the RTX 4090. Its driver is loaded.
- Owner decision: rule 7 changed. Claude Code now pushes to GitHub only when the owner asks, each time. The owner saved a token limited to the kiln repo on Kiln, in ~/.git-credentials. Cowork: note the new rule.

### 3 Nov 2026 — Claude Code, step 9 installed, not booted

- Owner's decisions: Hyprland stays, built from Kiln's own recipes rather than hyproverlay. Account `indy`, with sudo and no password. The rescue kernel check can wait.
- Installed from the live system: 124 packages, 102 ready-built, about 10 minutes. Results: results/desktop-2026-11-03/summary.txt. Recipes: overlay/.
- Wrote 10 recipes, for Hyprland 0.57.0, 8 libraries and Lua 5.5. hyproverlay is GPL-3 and Kiln is GPL-2, so none of its code was copied. Gentoo still masks the Hyprland names, so config/portage/package.unmask/ allows Kiln's copies only.
- Wired network: the log showed `systemd-networkd` never took the port. It now matches `en*`, not `Driver=igc`. The cause is likely but not proved. Test at boot.
- Hyprland 0.57 reads only Lua, so Omarchy's .conf files do not carry over. The first config is short, adapted from Hyprland's example. Cowork: the spec says configs borrowed from Omarchy and credited. Omarchy's files could not be fetched this session, so nothing is borrowed yet.
- Left out for now: `xdg-desktop-portal-hyprland`, needed for screen sharing, and a status bar and app launcher. Super+Return opens a terminal, Super+B opens Firefox.
- The hook blocks writes to /etc/udev/rules.d, so the WX 3200 is chosen in `kiln-session`, which looks up its current card number at login.
- The repo is copied to ~/Projects/kiln for `indy` on the Crucial. Claude Code 2.1.317 is copied from the live system. No sign-in details were copied.

### 3 Nov 2026 — Claude Code, first boot results

- mlrig kernel: 18 checks passed, 3 failed. Failed: wired link, internet, and the guard test on fake disks. Results: results/kernels-2026-11-03/summary.txt, and first-boot-6.18.60-gentoo-mlrig/ beside it, with IDs removed.
- The guard test failure is the test counting the Crucial's own writes. 31 of 32 passed, and the other disks stayed at 0 writes.
- Wired network: `systemd-networkd` ran, and its settings file is in place, but the log never shows `eno2` coming up. The same port works on the live system. Cause not found.
- Rescue kernel: not checked. There are no results for it. The login records show two boots, both the mlrig kernel, with root logged in only on the first.
- Boot order is 0000,0001,0002, with Ubuntu first. The `Kiln` entry has gone, and 0001 is `UEFI OS` on the Crucial. No session removed it. Cowork: docs/FIRST_BOOT.md tells the owner to choose Kiln.
- This session mounted the Crucial read-only and has unmounted it. All disks show 0 writes.
- Owner decision: Chromium is to be compiled for mlrig, after step 9 and once the step 11 settings are on. Not started.

### 3 Nov 2026 — Claude Code, step 8 built, not booted

- Two kernels, both 6.18.60: `6.18.60-gentoo-mlrig`, the default, and Gentoo's ready-built `6.18.60-gentoo-dist-bin`, the rescue. Boot loader `systemd-boot`. Results: results/kernels-2026-11-03/summary.txt. Kernel config: config/kernel/.
- NVIDIA 595.104.02 and `cp210x` are in, not yet tested. NVIDIA is on the mlrig kernel only, by owner's decision. Cowork: the spec's step 8 lists neither these nor the boot loader.
- The owner copied the guard to Kiln by hand, and set the root password. Checksums match the repo. The hook does nothing on Kiln until Claude Code is there in step 10.
- Firmware: added `Kiln`, not in the boot order. Removed the stale `Limine` and `UEFI OS` with the owner's approval, after proving their partitions are gone. Order is now 0000,0005.
- Other disks: all still at 0 writes and locked.
- Kernel 6.18 is Gentoo stable, by owner's decision. Ubuntu runs 7.3.0, so step 12 must record the difference. Cowork: the comparison is not purely about building for the CPU.
- Cowork: rule 1 wants a past snapshot in the boot menu. `systemd-boot` needs a menu entry written for each, and kernels on `/boot` are not in snapshots. For step 10.

### 3 Nov 2026 — Claude Code, ready-built base installed

- Installed on the Crucial by serial: 425 packages, 399 ready-built, in 28 minutes of machine time. Replaced the starter system with v3 packages, by owner's decision. Results: results/base-install-2026-11-03/summary.txt.
- Snapshot 1, base installed, is in place. `snapper` config: config/snapper/root. Hourly snapshots are off.
- Other disks: all still at 0 writes and locked. Boot order unchanged.
- 143 build tools stay on the generic starter build until step 11. Step 11 needs `--with-bdeps=y`.
- The fstab uses labels, so the public repo holds no unique IDs. config/etc/fstab.

### 3 Nov 2026 — Claude Code, step 7 trial

- Trial in memory, with `emerge --pretend`, and then deleted. No disk was touched. Results: results/base-trial-2026-11-03/summary.txt.
- Everything except Hyprland: 500 packages, 464 ready-built, 36 not, 2.6 GB to download. Of the 36, only `mesa` and `nvidia-drivers` look large. Compile times were not measured.
- The real install needs two settings not yet in config/portage/: `sys-kernel/installkernel dracut` and `media-libs/libvpx postproc`.
- The one-hour test cannot pass on this run, as planning and approvals took more than an hour. It needs a timed repeat run. Cowork and the owner to decide when.

### 3 Nov 2026 — Claude Code, build settings

- Wrote config/portage/ and config/etc/, in the repo only. No disk was written to. They go onto the Crucial in step 7.
- `-march=native`, the 21 CPU flags from `cpuid2cpuflags`, Gentoo's v3 ready-built packages, and `en_GB.UTF-8`.
- LTO and PGO are in config/portage/rebuild.conf, and turn on at step 11, by owner's decision. The Claude Doc says LTO by default. Cowork: this is a change of timing, not of the goal.
- tests/build-settings/check.py passes, including on fast and efficient cores. It read the files with Portage's parser, but the live image has no package tree, so the full Portage run comes in step 7.
- Cowork: Hyprland is not in Gentoo's main repo or GURU. The Gentoo wiki recommends the third-party `hyproverlay`. For the owner to decide at step 9.

### 3 Nov 2026 — Claude Code, disk layout

- With the owner's confirmation, wiped the Crucial by serial and laid it out: 2 GB boot partition, the rest btrfs, with sections `@`, `@home`, `@snapshots`, `@log` and `@cache`. No swap partition, by owner's decision. Exact commands: docs/DISK_LAYOUT.md.
- Read back after each change. A mount test and both filesystem checks passed.
- Other disks: write counts and lock flags did not change, and all still show 0 writes. Results: results/disk-layout-2026-11-03/.
- Boot order unchanged, with Ubuntu first. The firmware entries `Limine` and one `UEFI OS` now point at nothing. Left for the boot loader stage, with the owner's approval.
- Ubuntu may expect the Crucial at start-up. This could not be checked without opening a locked disk, and is unlikely as Omarchy was encrypted. If Ubuntu is slow to start, check this first.

### 2 Nov 2026 — Claude Code, hardware analysis

- Wrote docs/HARDWARE.md, with raw readings in results/hardware-2026-11-02/. Read-only. Drive health queries went to the Crucial only, by owner's decision.
- For step 6: `-march=raptorlake` does not match this chip. Prefer `-march=native`.
- For steps 7 and 8: the kernel warns of old microcode.
- For step 12: set the same audio output and power mode as the Ubuntu run, or the numbers will not compare.
- The RTX 4090 runs at x8, not x16, with the WX 3200 fitted. Probably the shared CPU lanes. The owner decided this does not matter, as the card is mainly for ML work.
- Owner answers, 3 Nov 2026: install the NVIDIA driver at some point. Install the `cp210x` driver, low priority, because the owner uses that adapter on Ubuntu to run GermOS on the HP. No self-test on the Crucial before the wipe.
- Owner decision, 3 Nov 2026: Ubuntu stays first in the boot order, and the owner presses F8 and chooses the Crucial to start Kiln. Kiln's boot loader must not stay first. Cowork: for the spec, Claude Doc first.
- Cowork: the spec's machine table says NVIDIA driver for compute, but no build step includes it. It needs a place, Claude Doc first. Claude Code suggests step 8, with the kernels.

### 2 Nov 2026 — Claude Code, step 3 complete

- The owner ran the installed-rule test: 32 passed, 0 failed. A new fake disk locked itself, using the rule as installed. Log: results/guard-proof-2026-11-02/installed-rule.log.
- Known gap: the hook crashing on start has not been tested live. It relies on `onFailure: block`.
- The hook sometimes blocks harmless commands, such as `which nvme`, because it reads command text. See lessons/hardware.md. Review this when the hooks are built in step 10.

### 2 Nov 2026 — Claude Code, disk guard installed

- Ran guard/install.sh with the owner's approval, and restarted Claude Code. The kernel shows every disk locked except the Crucial. No write reached any disk.
- The hook is live: it blocked zero-byte dd commands aimed at real disks, and the guard's own folder. Results are in results/guard-proof-2026-11-02/summary.txt.
- The hook also blocks Claude from running tests/guard/fake_disks.sh, so the owner runs it. Changes to the guard or its tests after this point go through the owner's hand.
- Step 5 needs care: use the /dev/disk/by-id/ path in full on every disk command, with no variables, and read the partition table back after any change. See lessons/hardware.md.

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
