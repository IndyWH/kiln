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
