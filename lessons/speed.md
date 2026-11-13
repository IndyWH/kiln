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

