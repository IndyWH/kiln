# Stage 1 spec: the personal prototype

23 Oct 2026 · Herath Herath

Copied from the Claude Doc, which is the source of truth: https://claude.ai/artifact/HWbM9gx3AcJzjfq5tVZEae

## Goal and done-when

Stage 1 proves the core idea on one real machine: Claude installs and tunes a Gentoo system for mlrig, with the owner only approving each step. Work starts in about a month, once Omarchy's cooling-off period on the Crucial drive ends.

Stage 1 is done when:

- Claude Code has installed the system from a live image, with the owner typing only approvals.
- mlrig boots into a Hyprland desktop from the Crucial drive.
- Every program is built for the i9-13900K, apart from a recorded list of fallbacks.
- All four rules pass their tests (see below).
- The measured gains against the Omarchy baseline are written down, good or bad.
- The owner has asked the sidekick for three things in plain words and got them. One of them is the cursor test: make the cursor a little bigger, with an amber outline.

Vision: [docs/VISION.md](VISION.md)

## Owner decisions

Each decision has a recommendation. The owner can accept it or choose otherwise. The Answer column records what the owner decided, and when.

| # | Decision | Recommendation | Why | Answer |
|---|---|---|---|---|
| 1 | How Stage 1 installs | Claude Code runs from a live image and installs by the Gentoo Handbook. The graphical installer waits for Stage 2 | Proves the sidekick can do the install before building a screen around it | Open |
| 2 | Start-up system | systemd | Its built-in timing tool splits boot time into firmware, loader, kernel and desktop, which the measurements need | Open |
| 3 | Disk encryption | None | Matches the owner's choice for the Ubuntu drive, and keeps a passphrase out of the boot-time numbers | Open |
| 4 | Display card | If the Radeon Pro WX 3200 is fitted, the desktop runs on it and the RTX 4090 stays for compute | Hyprland runs most smoothly on AMD graphics | Open |
| 5 | Sidekick key | One key opens or hides a Claude Code window | Simple for Stage 1. The in-terminal switch comes later | Open |
| 6 | Starting apps | A terminal and Firefox only | Everything else is requested from the sidekick, which tests it | Open |
| 7 | Protecting the other drives | Pick the Crucial drive by its serial number, and add a guard that blocks Claude from writing to any other disk | The same "storage bodyguard" idea that worked on GermOS | Open |
| 8 | Repository and licence | A new public GitHub repo, GPL-2 | Matches Gentoo's licence, so package recipes can move both ways | Open |
| 9 | Working name | Decided: Kiln Linux. Repo folder ~/Projects/kiln | Chosen by the owner on 23 Oct 2026. No distribution uses it | Kiln Linux. Decided 23 Oct 2026 |

## The machine and its boundaries

The target is mlrig. The install goes only on the Crucial P2 1 TB drive.

| Part | What Stage 1 does with it |
|---|---|
| Intel i9-13900K | Builds every program for it. It mixes fast and efficient cores, so the kernel must place work on the right kind of core |
| 96 GB DDR5 | Plenty of room to build several programs at once |
| Crucial P2 1 TB (DIMM.2_2, serial 2128E5B7DBBC) | The only disk Stage 1 may write to. Wiped after Omarchy's cooling-off period |
| Samsung 990 PRO, M.2_1 | Ubuntu 26.10. Never touched |
| Samsung 990 PRO, DIMM.2_1 (fastdata) | Models and datasets. Never touched |
| SATA drives | Never touched |
| RTX 4090 | NVIDIA driver for compute |
| Radeon Pro WX 3200, if fitted | Drives the display (decision 4) |
| Philips 49-inch ultrawide OLED | Always connected by HDMI, never DisplayPort, for live images |

The install makes its own boot partition on the Crucial drive and adds one firmware boot entry. Ubuntu's boot entry stays as it is.

Firmware start-up on mlrig already takes about 15.6 seconds before any operating system runs. Stage 1 cannot change that, so it is reported separately and not counted as the system's boot time.

## What Stage 1 builds, in order

1. **Baseline.** Before the wipe, measure Omarchy on the same Crucial drive (see Measuring the gain).
2. **Live start.** Boot a Gentoo live image from the Ventoy drive, connect to the network, install Claude Code and sign in.
3. **Guards first.** Before any disk work, install the guard that blocks writes to every disk except the Crucial drive. Prove it refuses a test write to another disk.
4. **Hardware analysis.** Claude reads the CPU, graphics, audio, storage and network, and writes a plain-English hardware report into the repo.
5. **Disk layout.** A boot partition and a btrfs root, with snapshots set up from the start.
6. **Build settings.** Gentoo's settings files are written for this CPU: build for the exact processor, list its instruction sets, and use link-time optimisation by default. Profile-guided optimisation is used where a package offers it.
7. **Ready-built base.** Install Gentoo's official ready-built packages first, so the system boots quickly. Check at kickoff which CPU level Gentoo currently offers these for.
8. **Two kernels.** A kernel configured for mlrig alone, with desktop-friendly scheduling and only the drivers it needs. Gentoo's ready-built generic kernel stays in the boot menu as the rescue kernel.
9. **Desktop.** Hyprland on Wayland, with configs borrowed from Omarchy and credited. PipeWire for audio. Then a terminal and Firefox.
10. **The sidekick.** Claude Code on one key, with a rules file that tells it the four rules, and hooks that enforce them (see below).
11. **Full rebuild.** In the background, rebuild every ready-built package for the i9-13900K, starting with the kernel, graphics and audio. Any package that fails gets safer settings, and the reason is written down.
12. **Measure again** and compare with the baseline.

## The four rules as tests

Each rule is enforced by the system, not left to Claude's good behaviour. Claude Code hooks run before any command that changes the system.

| Rule | How it is enforced | Test that proves it |
|---|---|---|
| 1. Nothing leaves the machine unbootable | A snapshot is taken automatically before every change. The rescue kernel is always in the boot menu. One `undo` command rolls back the last change | Break the desktop on purpose, then recover with `undo`. Boot the rescue kernel and a past snapshot from the boot menu |
| 2. Claude explains before it acts | Every change is written to a plain-English change log, and the owner approves it first | Ask for a change and check the explanation appears before anything runs, then check the log |
| 3. Usable in an hour, optimised later | Ready-built base first, rebuild in the background | Time from first boot of the live image to a working desktop: one hour or less |
| 4. Show the gain | The measurement script runs before and after | The comparison table exists and is filled in |

One more test sits under all four. With Claude switched off, the system still boots, updates with Gentoo's normal tools, and works.

## Measuring the gain

The fair comparison is Omarchy, because it runs on the same machine and the same Crucial drive. So the baseline must be measured **before** the wipe. That is the one job to do during the cooling-off month.

| Measure | How |
|---|---|
| Boot time | systemd's timing tool, split into firmware, loader, kernel and desktop. Firmware reported separately |
| Audio latency | The smallest PipeWire buffer that plays without dropouts while the machine is busy compiling |
| Responsiveness under load | How quickly the system reacts to a waiting task while every core is busy building |
| CPU speed | The existing benchmark script on mlrig: sysbench and 7-Zip |

The benchmark script writes test files on every drive mounted under its media folder. Check what is mounted before running it on either system.

Input lag is left out of Stage 1. Measuring it properly needs a high-speed camera or special hardware.

Ubuntu 26.10 on the 990 PRO is a useful second reference, because it uses ready-built x86-64-v3 packages. Its disk numbers are not comparable, because it is on a faster drive.

## Out of scope for Stage 1

- The graphical installer ISO
- Any machine other than mlrig
- A public release
- The in-terminal switch between Claude Code and the shell
- A slot for other AI models or a local model
- Choosing between alternative programs, such as Rust rewrites
- Choosing a different compiler for each package
- Secure Boot and disk encryption

## How the work runs

The team is the same as GermOS. The owner decides and approves. Cowork writes specs and reviews the work. Claude Code does the work, on Opus 5.5 at high effort.

One difference: in Stage 1, Claude Code is both the builder and the product being tested. Everything it does on the live system is the sidekick at work.

- One step per sitting. The owner reports back before the next step.
- Long output goes to a log file in the repo, not into chat.
- Every settings file Claude writes is saved in the repo, so the install can be repeated.
- GitHub pushes are done by the owner's own hand.

First action, during the cooling-off month: measure the Omarchy baseline.
