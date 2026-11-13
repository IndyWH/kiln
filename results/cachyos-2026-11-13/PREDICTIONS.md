# Baseline predictions, CachyOS, 13 Nov 2026

Written by Claude Code before any result of either run was read. Compared with v1's Ubuntu 26.10 run on 2 Nov 2026 (`results/ubuntu-26.10-2026-11-02` on the stage1-guards branch), made with the same `scripts/measure.sh`, in power mode performance. Ubuntu: sysbench 1708 / 39181, 7-Zip 10490 / 210923 MIPS, smallest clean audio buffer 256 samples, wake-up worst 11.03 ms.

Run 1, this folder: CachyOS's default power mode, balanced. Run 2, `cachyos-2026-11-13-2`: performance, as Ubuntu.

| Measure | Prediction |
|---|---|
| CPU, CachyOS performance against Ubuntu | sysbench and 7-Zip within 5%, either way. Mostly the same hardware work; v3 builds help 7-Zip a little at most |
| CPU, performance against balanced | Under 3% better with all cores busy, and under 2% on one thread |
| Audio, smallest clean buffer | 128 samples or smaller in both runs, one step better than Ubuntu's 256, from CachyOS's lower-latency kernel |
| Wake-up delay, worst, under full load | Under Ubuntu's 11 ms in both runs |

Note, 13 Nov 2026: Ubuntu was booted with gpu-unlock on the RTX 4090 (`gpu_unlock.targets=0000:01:00.0`). It changes only the GPU's tensor-core rate, so it does not touch these measures. See lessons/hardware.md.

## Results

Medians of 3 for the CPU. Raw data in this folder (balanced) and in `cachyos-2026-11-13-2` (performance).

| Measure | Ubuntu, performance | CachyOS, balanced | CachyOS, performance |
|---|---|---|---|
| sysbench, 1 thread | 1708 | 1726 | 1723 |
| sysbench, 32 threads | 39181 | 39222 | 39304 |
| 7-Zip MIPS, 1 thread | 10490 | 10814 | 10757 |
| 7-Zip MIPS, 32 threads | 210923 | 216652 | 215893 |
| Smallest clean audio buffer, all cores busy | 256 (5.33 ms) | 128 (2.67 ms) | 128 (2.67 ms) |
| Wake-up delay, worst, all cores busy | 11.03 ms | 3.28 ms | 3.14 ms |

| Prediction | Result |
|---|---|
| CPU within 5% of Ubuntu | Right: sysbench 0.3% to 0.9% faster, 7-Zip 2.4% to 2.5% faster, in performance mode |
| Performance mode under 3% better than balanced on all cores, under 2% on one | Right in its bounds, but there was no gain at all: every CPU figure is within 0.5%, either way, which is noise |
| Audio 128 samples or smaller, one step better than Ubuntu | Right: 128 in both runs; 64 had dropouts |
| Worst wake-up delay under Ubuntu's 11 ms | Right: 3.1 to 3.3 ms, about 3.5 times better |

On this machine, CachyOS's balanced mode is as fast as performance mode, so there is no reason to change it. Against Ubuntu, CachyOS matches it on the CPU and is clearly better on audio and responsiveness under load. Boot times are not measured yet: `scripts/measure.sh boot` needs 5 restarts.

