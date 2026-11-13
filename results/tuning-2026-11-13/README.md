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
