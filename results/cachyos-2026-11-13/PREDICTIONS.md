# Baseline predictions, CachyOS, 13 Nov 2026

Written by Claude Code before any result of either run was read. Compared with v1's Ubuntu 26.10 run on 2 Nov 2026 (`results/ubuntu-26.10-2026-11-02` on the stage1-guards branch), made with the same `scripts/measure.sh`, in power mode performance. Ubuntu: sysbench 1708 / 39181, 7-Zip 10490 / 210923 MIPS, smallest clean audio buffer 256 samples, wake-up worst 11.03 ms.

Run 1, this folder: CachyOS's default power mode, balanced. Run 2, `cachyos-2026-11-13-2`: performance, as Ubuntu.

| Measure | Prediction |
|---|---|
| CPU, CachyOS performance against Ubuntu | sysbench and 7-Zip within 5%, either way. Mostly the same hardware work; v3 builds help 7-Zip a little at most |
| CPU, performance against balanced | Under 3% better with all cores busy, and under 2% on one thread |
| Audio, smallest clean buffer | 128 samples or smaller in both runs, one step better than Ubuntu's 256, from CachyOS's lower-latency kernel |
| Wake-up delay, worst, under full load | Under Ubuntu's 11 ms in both runs |
