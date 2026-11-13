# Gentoo: dev-lang/rust with its own LLVM builds LLVM with C asserts on

**Status:** not sent to any project. Recorded here for developers who read this repo.
**Written by:** Claude Code, an AI tool, on 5 Nov 2026. Not yet reviewed by a person.

## The machine

mlrig: Intel i9-13900K, 96 GB DDR5-6400, RTX 4090, Radeon Pro WX 3200. Kiln Linux, built on Gentoo for amd64, with Clang 22 for this build.

## Who it affects

Only `USE=-system-llvm`, which is not the default. Gentoo's ready-built `rust-1.98.1-3` has `system-llvm` on, so it uses Gentoo's separate LLVM package and this section of the recipe does not build its LLVM. That package was not tested for asserts.

## The bug

In `dev-lang/rust-1.98.1`, lines 544 and 545 of the recipe write our flags over CMake's release flags, in `[llvm.build-config]`:

```
CMAKE_C_FLAGS_RELEASE = "${CFLAGS}"
CMAKE_CXX_FLAGS_RELEASE = "${CXXFLAGS}"
```

CMake's default for that setting includes `-DNDEBUG`, and LLVM's bundled build relies on it. Line 515 sets `assertions = false`, but that does not put `-DNDEBUG` back. So every C `assert` in LLVM stays compiled in and runs, and the compiler is slower.

## The evidence

A one-core test: `rustc` compiling a made-up 3,000-function file, with `-C opt-level=2 -C codegen-units=1`, three runs each, with `rust-bin` timed before and after each set as the control. `rust-bin` stayed at about 17.15 s throughout.

| LLVM built | No PGO | With PGO |
|---|---|---|
| With those lines | 26.76 s | 21.33 s |
| Without those lines | 22.82 s | 18.61 s |

- That is about 15% slower with PGO, and about 17% without it.
- The installed `libLLVM`, built by the recipe, took 21.24 s. It imports `__assert_fail`. The official `libLLVM` does not.
- The lab builds used Rust's own `x.py` and the same settings as the recipe, with only that section added or removed. Both builds with the section import `__assert_fail`.

## A possible fix, not tested

Adding `-DNDEBUG` to those two lines, when `USE=debug` is off. The lab removed the section instead, which also drops the user's flags from LLVM.

## What was checked and what was not

- Gentoo's tracker, 4 Nov 2026: no title match for `dev-lang/rust` with `NDEBUG`, `slow` or `performance`. A search of comments for `NDEBUG` found 11 Rust-titled bugs, none of them matching by title.
- Bugs 942884, 947892 and 949280 show LLVM assertion failures in Rust builds. They could be related, but no link was established.
- Bug 735154 made `system-llvm` the default, which is why few people would meet this.
- **Not done:** a build of the recipe with no local changes at all. The installed library comes from the recipe with Kiln's PGO hooks and compiler choice added, and those hooks do not set these flags.
- **Not done:** a test with GCC, or on any other machine. The size of the slowdown will vary.
- The cause was measured on this one test. Slower speed is the only effect looked at. Other effects of having asserts on were not studied.
