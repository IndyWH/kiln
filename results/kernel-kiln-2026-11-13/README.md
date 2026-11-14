# Kiln's own kernel, linux-cachyos-kiln, 13 Nov 2026

Owner asked for the full-fat kernel, set as the boot default. Built from CachyOS's own build script (`kernel/`), on 7.3.4, against the stock `linux-cachyos` 7.3.3 (EEVDF, thin LTO, CachyOS's AutoFDO and Propeller profiles, x86-64-v3).

Kiln's kernel: BORE scheduler, Clang full LTO, -O3, x86-64-v3, NVIDIA module built with it. Three stages, a restart after each:

1. BORE and full LTO, no profile yet.
2. Plus an AutoFDO profile taken on this machine with stage 1.
3. Plus a Propeller profile taken with stage 2: the final kernel.

Each stage gets `scripts/measure.sh run`; the final one also 5 boot timings, against 5 on stock.

## Predictions, written before any build

| | Against stock linux-cachyos |
|---|---|
| Stage 1, CPU (sysbench, 7-Zip) | Within 1%: these spend little time in the kernel |
| Stage 1, worst wake-up under load | Within the spread seen today, 2.9 to 3.3 ms; BORE favours interactive tasks, so if anything lower |
| Stage 1, audio | Still clean at 128 |
| Final, CPU | Within 1%: CachyOS's stock kernel already has its own profiles; ours are from this machine's work |
| Final, boot time | Within 0.5 s |

Most likely result: no measurable gain on these tests. The test that might show one is the worst wake-up under load.

## Stage 1, first boot and one run (`results/cachyos-2026-11-13-7`)

- Booted cleanly at 23:04: no failed services, network, screen at 5120x1440 120 Hz with VRR, the 4090 at x16 with its module 620.70.06, guard OK, snapshots taken. Kernel stage of boot 0.98 s. Two ACPI firmware messages about the 4090's slot appear on the stock kernel too.
- Made the default after that: `BOOT_ORDER="*kiln, *, *lts, *fallback, Snapshots"`; the stock kernel updated to 7.3.4 the same minute.

| | sysbench 1 / 32 | 7-Zip 1 / 32 | Audio, worst timing | Worst wake-up, loaded |
|---|---|---|---|---|
| Stock 7.3.3, six runs today | 1723-1730 / 39209-39325 | 10754-10814 / 215687-216652 | 128, 0.26-0.62 | 2.43-3.28 ms |
| Kiln stage 1 | 1727 / 39264 | 10804 / 216937 | 128, 0.03 | 2.08 ms |

CPU: the same, as predicted. Worst wake-up and audio timing: better than every stock run today, but one run; repeats against stock 7.3.4 come with the boot tests.

## Stage 2, AutoFDO partly applied (`results/cachyos-2026-11-14`)

Booted cleanly at 00:45 on 14 Nov. One run: sysbench 1728 / 39215, 7-Zip 10788 / 217054, audio 128 with worst timing 0.03, worst wake-up 2.07 ms. Level with stage 1 on everything.

Found after: the kernel passes the linker its AutoFDO and Propeller settings only with thin LTO. With full LTO the code is generated in the linker, so this stage got only the compile-time part of the profile, and its Propeller code map was 460 bytes instead of megabytes. Google's tool refused it ("Fewer than 0.05% recorded jumps are converted"). `kernel/kiln-lto-profiles.patch` passes the same settings for full LTO; stage 2 is rebuilt with it. Upstream supports profiles only with thin LTO; full LTO with profiles is untested upstream, so Kiln goes beyond what CachyOS and the kernel test.

Rebuilt with the patch, 01:43: Propeller code map 8.1 MB (was 460 bytes), 612 functions split into hot and cold parts (was none), so AutoFDO's code-generation part now applies too. Build warnings identical in number and kind to the first stage 2 build. The first stage 2's packages are kept in ~/.cache/kiln-kernel/keep/.

## Stage 3, the final kernel (14 Nov)

- Recording with the rebuilt stage 2, 08:04: perf 800 MB. `llvm-profgen` then rejected it ("Invalid perf script input", cause not found); stage 3 uses stage 1's AutoFDO profile, so not needed. Google's tool made the Propeller profiles from the same recording: 2543 hot functions, its layout score for calls between functions +101%.
- Built 08:24 to 08:43: build warnings identical in number and kind; 2401 functions split hot and cold (stage 2: 612); the profile's hottest functions sit together in memory.
- Booted cleanly at 08:51. Two runs: `results/cachyos-2026-11-14-2` (owner using the PC) and `-3`.

## Against stock 7.3.4, the same day

| | sysbench 1 / 32 | 7-Zip 1 / 32 | Audio, worst timing | Worst wake-up, loaded |
|---|---|---|---|---|
| Stock 7.3.4, two runs (`-4`, `-5`) | 1722-1728 / 39158-39206 | 10803-10834 / 216622-217128 | 128, 0.60-0.63 | 2.97-3.96 ms |
| Kiln stage 3, two runs | 1721-1726 / 39099-39213 | 10824-10831 / 216995-217391 | 128 and 256, 0.02-0.53 | 2.12-2.20 ms |
| All Kiln stages, five runs | | | 0.02-0.53 | 2.07-2.20 ms |
| All stock, six runs (7.3.3 and 7.3.4) | | | 0.26-0.63 | 2.43-3.96 ms |

Boot, 5 each (`journalctl -b -N`, "Startup finished"), median (range):

| | Kernel stage | Start-up files | Desktop ready after | Total |
|---|---|---|---|---|
| Stock 7.3.4 | 0.980 s (0.912-0.997) | 4.50 s | 5.13 s | 37.9 s |
| Kiln stage 3 | 0.911 s (0.905-0.915) | 4.50 s | 5.12 s | 37.8 s |

## Verdict, against the predictions

- CPU: within 1%, as predicted. No gain: the first round's small lead was against stock 7.3.3; stock 7.3.4 is level.
- Boot: within 0.5 s, as predicted. The kernel stage is 70 ms faster, lost in a 38 s boot: firmware takes 21 s and the Limine menu waits 5 s (`timeout: 5`).
- Worst wake-up under full load: the one real gain, better than predicted. Every Kiln run (2.07 to 2.20 ms) beat every stock run (2.43 to 3.96 ms), across 11 runs; most likely BORE.
- Audio: 128 samples clean on both. Kiln's worst timing was lower in four of five runs; not proven.
- Kept as the default. Its costs are in `kernel/README.md`: rebuild for each new kernel, and after each NVIDIA update.
