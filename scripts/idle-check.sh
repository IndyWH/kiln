#!/usr/bin/env bash
# Kiln: how the machine behaves when idle. Package power over 60 s with nothing running,
# then wake-up delay over 60 s with nothing else running. Appends one line to a CSV.
#   sudo scripts/idle-check.sh LABEL CSV
# Run with the desktop idle: no typing, no video. Changes nothing.
set -eu
export LC_ALL=C
label=${1:?label}; csv=${2:?csv file}
rapl=/sys/class/powercap/intel-rapl:0/energy_uj
max=$(cat /sys/class/powercap/intel-rapl:0/max_energy_range_uj)
sleep 10  # let things settle
e0=$(cat $rapl); t0=$(date +%s.%N)
sleep 60
e1=$(cat $rapl); t1=$(date +%s.%N)
watts=$(awk -v a="$e0" -v b="$e1" -v m="$max" -v t0="$t0" -v t1="$t1" \
    'BEGIN { d = b - a; if (d < 0) d += m; printf "%.2f", d / 1e6 / (t1 - t0) }')
out=$(cyclictest --policy=other -t 8 -i 1000 -D 60 -q 2>&1)
avg=$(echo "$out" | awk '/Avg:/ { for (i = 1; i <= NF; i++) if ($i == "Avg:") { s += $(i+1); n++ } } END { printf "%.1f", s / n }')
worst=$(echo "$out" | awk '/Max:/ { for (i = 1; i <= NF; i++) if ($i == "Max:" && $(i+1) > m) m = $(i+1) } END { print m }')
[ -s "$csv" ] || echo "date,label,governor,preempt,idle_package_watts,wakeup_avg_us,wakeup_worst_us" >"$csv"
gov=$(cat /sys/devices/system/cpu/cpuidle/current_governor)
pre=$(grep -o '([a-z]*)' /sys/kernel/debug/sched/preempt | tr -d '()')
echo "$(date '+%F %H:%M'),$label,$gov,$pre,$watts,$avg,$worst" | tee -a "$csv"
