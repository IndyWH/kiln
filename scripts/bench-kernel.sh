#!/usr/bin/env bash
# Kiln Linux: a quick benchmark of the running kernel, about 10 minutes.
# Run it once on each kernel, with the machine otherwise idle, then compare
# results/kernel-bench/table.csv. Add --short for a 1 minute check of the script.
#
# Writes to results/kernel-bench/ and a temporary folder in memory. Sets the CPU
# governor to performance, and puts it back at the end.
# scripts/measure.sh stays the full comparison with Ubuntu.

set -u
export LC_ALL=C
SELF=$(readlink -f "$0")
cd "$(dirname "$SELF")/.." || exit 1

SHORT=0
[ "${1:-}" = --short ] && SHORT=1
if ((SHORT)); then
    REPEATS=1 SB_SECS=2 SEVEN_PASSES=1 RESP_SECS=5 SETTLE=3 COMPILES=0
else
    REPEATS=3 SB_SECS=10 SEVEN_PASSES=2 RESP_SECS=30 SETTLE=10 COMPILES=3
fi

KERNEL=$(uname -r)
CORES=$(nproc)
SOURCE=/usr/src/linux-7.3.1-gentoo
WORK=/tmp/kiln-bench-$$
DIR=results/kernel-bench/$KERNEL-$(date +%Y%m%d-%H%M)
((SHORT)) && DIR=$DIR-short
TABLE=results/kernel-bench/table.csv
LOG=$DIR/raw.log
SEVEN=$(command -v 7zz || command -v 7z)
GOVERNORS=/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
OLD_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
LOAD_PIDS=()

for tool in sysbench hackbench cyclictest gcc; do
    command -v "$tool" >/dev/null || { echo "$tool is missing."; exit 1; }
done
[ -n "$SEVEN" ] || { echo "7-Zip is missing."; exit 1; }
mkdir -p "$DIR" "$WORK"

median() { sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) * 0.5)] }'; }
set_governor() { for f in $GOVERNORS; do echo "$1" | sudo tee "$f" >/dev/null; done; }
say() { echo "$*" | tee -a "$LOG"; }

stop_load() {
    for p in "${LOAD_PIDS[@]}"; do kill -TERM -- "-$p" 2>/dev/null; done
    ((${#LOAD_PIDS[@]})) && wait "${LOAD_PIDS[@]}" 2>/dev/null
    LOAD_PIDS=()
}
cleanup() { stop_load; set_governor "$OLD_GOVERNOR"; rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

set_governor performance
say "Kernel: $KERNEL"
say "Compiler of this kernel: $(cut -d'(' -f2- /proc/version | cut -c1-70)"
say "Load before starting: $(cut -d' ' -f1-3 /proc/loadavg)"
say "Governor during the test: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor), usually $OLD_GOVERNOR"

# Task switching. Lower is better.
hack() { for ((i = 0; i < REPEATS * 2 - 1; i++)); do
    hackbench "$@" | tee -a "$LOG" | awk '/^Time:/ { print $2 }'; done | median; }
say "Task switching, processes and sockets"
HACK_SOCKET=$(hack --groups 16 --loops 10000)
say "Task switching, threads and pipes"
HACK_PIPE=$(hack --threads --pipe --groups 16 --loops 10000)

# The same CPU tests as Ubuntu's baseline. Higher is better.
sb() { for ((i = 0; i < REPEATS; i++)); do
    sysbench cpu --cpu-max-prime=20000 --threads="$1" --time="$SB_SECS" run |
        tee -a "$LOG" | awk '/events per second/ { print $NF }'; done | median; }
seven() { for ((i = 0; i < REPEATS; i++)); do
    "$SEVEN" b "$SEVEN_PASSES" -mmt="$1" -md25 | tee -a "$LOG" | awk '/^Tot:/ { print $NF }'; done | median; }
say "CPU speed: sysbench"
SB_1=$(sb 1)
SB_ALL=$(sb "$CORES")
say "CPU speed: 7-Zip"
SEVEN_1=$(seven 1)
SEVEN_ALL=$(seven "$CORES")

# Real work: compile a standard kernel, in memory. Lower is better.
COMPILE=skipped
if ((COMPILES)) && [ -d "$SOURCE" ]; then
    say "Compiling a kernel, $COMPILES times"
    COMPILE=$(for ((i = 0; i < COMPILES; i++)); do
        rm -rf "$WORK/kernel"
        make -s -C "$SOURCE" O="$WORK/kernel" x86_64_defconfig >>"$LOG" 2>&1
        begin=$(date +%s.%N)
        make -s -C "$SOURCE" O="$WORK/kernel" -j"$CORES" >>"$LOG" 2>&1
        end=$(date +%s.%N)
        echo "$begin $end" | awk '{ printf "%.1f\n", $2 - $1 }'
    done | median)
    rm -rf "$WORK/kernel"
fi

# Responsiveness: how fast a waiting task wakes up while every core compiles.
# The same kind of load and test as scripts/measure.sh, but not equal to it, so do
# not compare these figures with Ubuntu's. Lower is better.
say "Responsiveness under load, $RESP_SECS seconds"
awk 'BEGIN { for (i = 0; i < 4000; i++) {
    printf "static int t%d[64];\n", i
    printf "int f%d(int x, int y) { int s = x; for (int i = 0; i < 64; i++) {", i
    printf " t%d[i] = (s * %d + y) ^ i; if (t%d[i] & 1) s += t%d[i]; else s -= i * y; }", i, i + 3, i, i
    printf " return s; }\n" } }' >"$WORK/load.c"
for ((i = 0; i < CORES; i++)); do
    setsid bash -c "while :; do gcc -x c -O2 -pipe -S -o /dev/null $WORK/load.c; done" >/dev/null 2>&1 &
    LOAD_PIDS+=($!)
done
sleep "$SETTLE"
sudo cyclictest --policy=other -t 8 -i 1000 -D "$RESP_SECS" -q --laptop -h 100000 >"$WORK/wake.log" 2>&1
stop_load
cat "$WORK/wake.log" >>"$LOG"
WAKE=$(awk '
    /^[0-9]/ { for (i = 2; i <= NF; i++) { c[$1 + 0] += $i; total += $i } }
    /Max Latencies:/ { for (i = 4; i <= NF; i++) if ($i + 0 > max) max = $i + 0 }
    END {
        if (!total) { print "failed failed failed"; exit }
        p99 = p999 = -1
        for (u = 0; u <= 100000; u++) {
            seen += c[u]
            if (p99 < 0 && seen >= total * 0.99) p99 = u
            if (p999 < 0 && seen >= total * 0.999) p999 = u
        }
        print p99, p999, max
    }' "$WORK/wake.log")
read -r WAKE_P99 WAKE_P999 WAKE_WORST <<<"$WAKE"

STAMP=$(date '+%F %H:%M')
[ -e "$TABLE" ] || echo "date,kernel,hackbench_socket_s,hackbench_pipe_s,sysbench_1,sysbench_all,sevenzip_1,sevenzip_all,compile_s,wake_p99_us,wake_p999_us,wake_worst_us" >"$TABLE"
((SHORT)) || echo "$STAMP,$KERNEL,$HACK_SOCKET,$HACK_PIPE,$SB_1,$SB_ALL,$SEVEN_1,$SEVEN_ALL,$COMPILE,$WAKE_P99,$WAKE_P999,$WAKE_WORST" >>"$TABLE"

{
    echo "Kernel: $KERNEL, $STAMP"
    echo "Lower is better:"
    echo "  Task switching, sockets:  $HACK_SOCKET s"
    echo "  Task switching, pipes:    $HACK_PIPE s"
    echo "  Compile a kernel:         $COMPILE s"
    echo "  Wake-up delay, 99%:       $WAKE_P99 microseconds"
    echo "  Wake-up delay, 99.9%:     $WAKE_P999 microseconds"
    echo "  Wake-up delay, worst:     $WAKE_WORST microseconds"
    echo "Higher is better:"
    echo "  sysbench, 1 thread:       $SB_1"
    echo "  sysbench, all threads:    $SB_ALL"
    echo "  7-Zip, 1 thread:          $SEVEN_1"
    echo "  7-Zip, all threads:       $SEVEN_ALL"
} | tee "$DIR/summary.txt"
