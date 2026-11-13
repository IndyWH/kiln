# Two live kernel settings from CachyMod, 13 Nov 2026

Owner agreed: try two settings CachyMod suggests, on the stock CachyOS kernel (7.3.3-1-cachyos), one at a time, each switched live and switched back after. Baseline: today's `results/cachyos-2026-11-13` (idle governor `menu`, preemption `full`, power mode balanced), plus an idle check run now.

- **TEO idle governor**: `teo` instead of `menu` in /sys/devices/system/cpu/cpuidle/current_governor. Claimed smoother on Intel 11th to 14th gen; no numbers given.
- **Lazy preemption**: `lazy` instead of `full` in /sys/kernel/debug/sched/preempt.

Each gets a full `scripts/measure.sh run` (all cores busy) and `scripts/idle-check.sh` (idle package power over 60 s, then wake-up delay with nothing else running, 60 s).

## Predictions, written before any run

| Setting | Under full load (measure.sh) | Idle (idle-check.sh) |
|---|---|---|
| TEO | No change beyond noise: CPU within 1%, audio 128, worst wake-up within 1 ms. With every core busy the idle governor has little to do | Idle power within 5%, either way. Average wake-up delay a little lower, up to 10%; TEO's claim is about this case |
| Lazy preemption | CPU 0% to 1% faster; worst wake-up delay higher, 3 to 6 ms; audio still clean at 128 | No change beyond noise |

If neither shows a gain beyond the run-to-run spread, both go back to the defaults and stay there.

## Results, first round

One `measure.sh run` each. Earlier runs today for the spread: the baseline (`cachyos-2026-11-13`) and the performance-mode run (`-2`), both with menu and full.

| | sysbench 1 / 32 threads | 7-Zip 1 / 32 threads | Audio | Worst wake-up, loaded | Idle watts | Idle wake-up avg / worst |
|---|---|---|---|---|---|---|
| Baseline, menu + full | 1726 / 39222 | 10814 / 216652 | 128 | 3.28 ms | 9.49 | 58.2 / 102 µs |
| Performance mode run (-2) | 1723 / 39304 | 10757 / 215893 | 128 | 3.14 ms | | |
| TEO (-3) | 1724 / 39227 | 10756 / 215687 | 128 | 3.25 ms | 9.85 | 58.1 / 182 µs |
| Lazy (-4) | 1727 / 39254 | 10755 / 216335 | 128 | 2.43 ms | 9.64 | 58.1 / 84 µs |

- **TEO: no gain.** Under load, as predicted, nothing changed. Idle: average wake-up unchanged, not lower as predicted; power 4% higher, within the predicted 5% but the wrong way; worst idle wake-up higher. Back to menu.
- **Lazy: CPU no change**, the low end of the 0% to 1% predicted. **Worst wake-up under load 2.43 ms, lower, where I predicted higher.** That is outside the two earlier runs (3.14 and 3.28 ms), but one run proves little, so it is repeated below, full and lazy back to back.

## Repeat: full and lazy back to back

| | sysbench 1 / 32 | 7-Zip 1 / 32 | Audio | Worst wake-up, loaded |
|---|---|---|---|---|
| Full (-5) | 1727 / 39209 | 10758 / 215919 | 128 | 2.93 ms |
| Lazy (-6) | 1730 / 39325 | 10754 / 216125 | no data* | 3.17 ms |

\* The monitor went to standby at 21:39, during this run (its USB hub dropped off), and the test's sound output is the screen's DisplayPort audio, so nothing played. Not lazy's doing; the first lazy run was clean at 128.

## Verdict

**Neither setting gains anything. Both stay at the defaults, menu and full; nothing was made permanent.**

- Over five loaded runs on full, worst wake-up ranges 2.93 to 3.28 ms; lazy gave 2.43 then 3.17 ms. The first lazy figure was luck.
- CPU figures for all six runs sit within 0.6% of each other.
- My predictions: TEO under load right; TEO at idle wrong (no lower wake-up; slightly more power). Lazy's CPU right (no gain); lazy's worse worst-case wrong (no change).
