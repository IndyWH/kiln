# CachyOS against Gentoo: five programs

Owner asked, 13 Nov 2026: how do the five programs of v1's CPU setting test run on CachyOS, against Kiln v1 on Gentoo? Same machine, same test files, same work, CPU only, same cores, 5 rounds. Gentoo's numbers are v1's `x86-64-v3` builds, from `results/cpu-level/runs.csv` on the `stage1-guards` branch, 11 Nov 2026. Gentoo is no longer installed, so it cannot be rerun.

| Program | Gentoo, v1 | CachyOS |
|---|---|---|
| dav1d | 1.5.4, built by Kiln: Clang, `-O2`, v3, static | CachyOS's v3 package, 1.5.4 |
| LightCraft | 0.18.1, built by Kiln: Rust `opt-level=3`, one codegen unit, v3 | 0.18.1, built with Kiln's v3 makepkg settings and Arch's Rust |
| SQLite | 3.53.4 single file built into `speedtest1`: Clang, `-O2`, v3, threads off | v1's `speedtest1.c`, linked to CachyOS's v3 `libsqlite3` 3.54.0 |
| darktable | 5.4.1, built by Kiln with Gentoo's settings, v3 | CachyOS's v3 package, 5.6.2 |
| RawTherapee | 5.12, built by Kiln with Gentoo's settings, v3 | CachyOS's v3 package, 5.13 |

Also different: the kernel (Gentoo 7.3.1 built by Kiln, against CachyOS 7.3.3 with its own scheduler), and the system libraries. So a difference shows what moving to CachyOS did, but not which part caused it. The CPU power settings are the defaults on both: `intel_pstate`, `powersave`, `balance_performance`.

## Predictions, written before any run

| Program | Gentoo | Prediction for CachyOS | Why |
|---|---|---|---|
| dav1d | 1.858 s | Within 2%, either way | Same version; its hand-written assembly does the work |
| LightCraft | 0.900 s | Within 3%, either way | Same source and level; only the compilers' versions differ |
| SQLite | 9.596 s | 0% to 8% slower | A shared library built with threads on, against one file built in with threads off |
| darktable | 1.277 s | Within 5%, either way | Newer version and `-O3`; cannot tell which caused a change |
| RawTherapee | 1.977 s | Within 5%, either way | As darktable |

Overall: on the two programs with the same version, dav1d and LightCraft, CachyOS is within 3% of Gentoo.

Added before any run, 13 Nov 2026. Two more rows, to tell the system apart from the build:

| Row | Prediction | Why |
|---|---|---|
| v1's exact recipe rebuilt here, for SQLite, dav1d and LightCraft: same source and flags, Clang 23 instead of 22 | Within 2% of Gentoo, each | Only the system differs, and these programs make few calls into it |
| LightCraft with Kiln's v3 makepkg settings: GCC `-O3` for its C parts, Cargo's default 16 codegen units | 0% to 5% slower than v1's recipe | One codegen unit lets the compiler see more of the program at once |

Added after the first run, before testing it, 13 Nov 2026: LightCraft came out 21% faster than on Gentoo, with the same picture. v1's Gentoo kernels set transparent huge pages to `madvise`; CachyOS's sets `always`. Prediction: with CachyOS switched to `madvise` for a moment, LightCraft slows back to about 0.90 s.

## Results

13 Nov 2026, kernel 7.3.3-1-cachyos. Median of 5 rounds; the spread between rounds was under 1% everywhere. Raw times in `runs.csv`. Outputs checked first: dav1d's frame checksums and LightCraft's picture match v1's on Gentoo exactly, for both builds.

| Program | Gentoo, v1 | CachyOS, what Kiln runs | v1's recipe rebuilt here |
|---|---|---|---|
| dav1d | 1.858 s | 1.839 s, **1.0% faster** | 1.842 s, 0.9% faster |
| LightCraft | 0.900 s | 0.711 s, **21.0% faster** | 0.703 s, 21.9% faster |
| SQLite | 9.596 s | 9.063 s, **5.6% faster** | 9.509 s, 0.9% faster |
| darktable | 1.277 s | 1.283 s, **0.5% slower** | |
| RawTherapee | 1.977 s | 1.822 s, **7.8% faster** | |

CachyOS is as fast or faster on all five; darktable's 0.5% is inside the noise between machines' states.

### The predictions

| Prediction | Result |
|---|---|
| dav1d within 2% | Right: 1.0% faster |
| LightCraft within 3% | Wrong: 21% faster. Cause found, below |
| SQLite 0% to 8% slower | Wrong: 5.6% faster. CachyOS's shared, thread-safe library beat a single file built in with threads off |
| darktable within 5% | Right: 0.5% slower |
| RawTherapee within 5% | Wrong: 7.8% faster. Newer version, 5.13 against 5.12, so the cause is not known |
| v1's recipe rebuilt here within 2% of Gentoo | Right for SQLite and dav1d, 0.9% faster each. Wrong for LightCraft, 21.9% faster |
| LightCraft with Kiln's makepkg settings 0% to 5% slower than v1's recipe | Right: 1.1% slower |
| Huge pages set to `madvise` bring LightCraft back to about 0.90 s | Right, mostly: 0.86 s |

### Why LightCraft is faster: huge pages

The same LightCraft build, timed with transparent huge pages set each way, 5 runs each, twice in turn:

| Huge pages | Time |
|---|---|
| `always`, CachyOS's default | 0.696 s to 0.703 s |
| `madvise`, v1's Gentoo kernels | 0.856 s to 0.869 s |

So CachyOS's memory setting gives LightCraft about 19%. The other 4%, 0.86 s against 0.90 s, is the rest of the system and the newer compilers. dav1d and darktable barely changed, perhaps because their memory use is small, or because they already ask for huge pages; not tested.

### What it means

Moving to CachyOS lost nothing on any of the five, and gained up to 21%. The biggest gain came from a kernel setting, not from how any program was built: the same pattern as v1, where the large gains were a missing flag and a linker.
