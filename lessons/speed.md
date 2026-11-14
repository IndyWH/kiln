# Speed

Measuring speed on CachyOS, and what made a difference.

- CachyOS's kernel sets transparent huge pages to `always` (defrag `defer+madvise`). v1's Gentoo kernels used `madvise`. On LightCraft's photo render this alone was about 19%: 0.70 s against 0.86 s. Switch it for a test with `echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled`; it resets at restart. 13 Nov 2026, `results/cachyos-vs-gentoo/`.
- CachyOS against v1's Gentoo, five programs, 13 Nov 2026: as fast or faster on all five, from 0.5% slower (darktable, noise) to 21% faster (LightCraft).
- Check outputs before timing. dav1d's frame checksums and LightCraft's picture must match v1's: `5dc6df32af29d714a1f37f61729a4a6e` and `980a227c7f528843`. LightCraft's GPU picture differs (`6de59cd0acb28e9c`), which shows v1 ran on the CPU.
- `LIGHTCRAFT_GPU=0` keeps LightCraft on the CPU. With the GPU on, a single render is slower, 0.91 s against 0.70 s, as starting the GPU costs more than it saves.
- SQLite's `speedtest1.c` needs `-DSQLITE_ENABLE_RTREE` itself, or it stops at once, even when the library has R-Tree.
- The disk guard checks every program a script runs before it starts. Build in one script and time in another, and make links such as `current` before the timing script is named in any command, even `bash -n`.
- raw.pixls.us answers `getfile.php/2414` with a short error text; the full address in LightCraft's `xtask/src/raw_samples.rs` works. Always check the checksum.
- Baseline, 13 Nov 2026, `results/cachyos-2026-11-13/PREDICTIONS.md`: CachyOS matches Ubuntu's CPU figures (0.3% to 2.5% faster), and under full load gives clean audio at 128 samples against 256, and a worst wake-up delay of 3.1 ms against 11.0 ms.
- Power mode performance gains nothing over balanced on this machine: all CPU figures within 0.5%. Leave it on balanced.
- `pgrep -f` matches the shell that runs it, if that shell's command line holds the same words. A wait loop `while pgrep -f "[m]easure.sh run"` written into the same command waited for itself. Start the second job from a separate command, or wait on a PID.

- CachyMod's TEO idle governor and lazy preemption, tested live on 7.3.3-1-cachyos, 13 Nov 2026: no gain from either. TEO used 4% more power at idle; lazy's one good worst-case figure did not repeat. Keep menu and full. Repeat any surprising single run before acting on it. `results/tuning-2026-11-13/`.
- measure.sh's audio test plays through the monitor's DisplayPort audio. If the screen sleeps or is switched off mid-run, the audio line reads no-data and `Setup` shows no screen. Keep the screen awake for a full run.
- Kernel profiling with perf needs `kernel.kptr_restrict=0` while recording: CachyOS sets 2, which hides kernel addresses even from root, and `llvm-profgen` then says "no kernel is found in mmap events". `kernel/profile.sh` lowers it only while recording. On this hybrid CPU, `-e BR_INST_RETIRED.NEAR_TAKEN:k -b` records on both P and E cores, and llvm-profgen reads both.
- The disk guard reads `x=${1:?some message}` unquoted as separate words; a message containing the word "source" looked like a command running a file called by the next word. Quote such lines.
- The kernel's `scripts/Makefile.autofdo` and `Makefile.propeller` pass the linker its profile settings only with thin LTO. With full LTO the code is generated in the linker, so AutoFDO is only partly used (no split functions) and the Propeller code map is near empty (460 bytes, not 8 MB). Check `llvm-readelf -S vmlinux | grep bb_addr_map` before profiling for Propeller. `kernel/kiln-lto-profiles.patch` fixes it.
- `makepkg` stops with "already built" if the stage folder holds packages of the same name and version. Move them aside before a rebuild, never install from that folder without checking the files are new.
