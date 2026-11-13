# Decision: Kiln moves to CachyOS

13 Nov 2026. Decided by the owner, Wajira.

## The decision

Kiln v2 is built on CachyOS, which is based on Arch Linux, not on Gentoo. The Crucial P2 is wiped and CachyOS is installed fresh. Kiln v1, on Gentoo, stays on the `stage1-guards` branch as history.

## Why

Kiln v1 measured what building everything for this CPU is worth, on mlrig (i9-13900K, RTX 4090):

- The CPU setting gives nothing beyond ready-built `x86-64-v3`. On five programs, `native` was never better than `v3`. Ordinary code (SQLite) and hand-written code (dav1d) gained nothing; image work gained 1.5% to 6%, all at `v3`.
- What did pay was LTO and profile-guided builds of a few heavy programs: a compiler rebuilt this way compiled a kernel 12.5% faster. Expert ready-built packages, such as `rust-bin`, already have this. Our best Rust only tied it.
- Gentoo cost a lot: 10 recipes written for Hyprland, Chromium withdrawn, slow updates.

CachyOS already ships what v1 set out to prove: ready-built `v3` and `v4` packages, LTO and profile-built kernels and programs, and current Hyprland. Arch moves within days of upstream. The owner wants Kiln on the bleeding edge.

So Kiln stops being about compiling. What is new in Kiln is Claude as the superuser who runs the machine, and the safety that makes that sensible. See [PHILOSOPHY.md](PHILOSOPHY.md).

## What carries over from v1

- The disk guard: `guard/`, `tests/guard/`.
- Snapshots, `undo` and `restore`: `sidekick/`. Its ask-first rules are to be rewritten to inform instead.
- The Hyprland settings with Omarchy's look: `config/hypr/`.
- Lessons about this machine's hardware, desktop, sound and network: `lessons/`.
- `scripts/measure.sh` and the habit: predict, measure, write the result down, good or bad.

Left behind on `stage1-guards`: the Portage recipes and hooks, the kernel builds, the Rust profile and BOLT work, and the lessons about building.

## Still open

- Which CachyOS edition, boot loader and snapshot tool. Settled in the install guide.
- The vision and Stage 1 spec say Gentoo. Cowork revises them.
