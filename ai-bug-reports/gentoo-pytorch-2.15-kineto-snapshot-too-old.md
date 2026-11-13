# Gentoo: pytorch-2.15.0 does not compile with the Kineto snapshot it asks for

**Status:** not sent to any project. Recorded here for developers who read this repo.
**Written by:** Claude Code, an AI tool, on 5 Nov 2026. Not yet reviewed by a person.

## The machine

mlrig: Intel i9-13900K, 96 GB DDR5-6400, RTX 4090, Radeon Pro WX 3200. Kiln Linux, built on Gentoo for amd64, with GCC 16.2.1.

## The bug

With `USE=kineto`, `sci-ml/pytorch-2.15.0` stops compiling at `kineto_shim.cpp`:

```
torch/csrc/profiler/kineto_shim.cpp:552:35: error: 'HARDWARE_COUNTERS' is not a member of 'libkineto::ActivityType'
```

The recipe removes PyTorch's own copy of Kineto and requires Gentoo's: `kineto? ( ~sci-ml/kineto-0.4.0_p20260805 )`. That snapshot is older than the code PyTorch names:

| Where | `HARDWARE_COUNTERS` |
|---|---|
| Installed `/usr/include/kineto/ActivityType.h`, `kineto-0.4.0_p20260805-r1` | Missing |
| Kineto's `main` branch on GitHub, read 5 Nov 2026 | Present |
| `pytorch-2.15.0-unbundle_kineto.patch` in Gentoo | Does not mention it |

## How to repeat it

1. Enable `kineto` for `sci-ml/pytorch`. The recipe keeps it off by default.
2. Run `emerge =sci-ml/pytorch-2.15.0`.

This machine also had `cuda` and `distributed` on, as well as others. It failed once, on the recipe as shipped, with no local patch. The log is in `results/pytorch-2026-11-03/emerge.log`, at line 2204. Compiler flags were not reduced to Gentoo's defaults, but a missing name does not depend on them.

## A workaround, not a proper fix

Kiln removes the one `case` line, in `config/portage/patches/sci-ml/pytorch-2.15.0/`. PyTorch then built and passed `scripts/test-pytorch.py`, which does not test the profiler. The better fix is probably a newer Kineto snapshot, but that was not tried.

## What was checked and what was not

- Gentoo's tracker, 5 Nov 2026: no PyTorch-titled bug mentions 2.15, and a comment search for `HARDWARE_COUNTERS` found nothing.
- Portage tree dated 3 Nov 2026. Gentoo's web view of the tree returned an error when read, so a newer fix may exist.
- Not checked: which Kineto commit PyTorch 2.15.0 expects, whether the failure happens without `cuda`, and PyTorch's other versions.
