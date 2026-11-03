#!/usr/bin/env bash
# Kiln Linux: how fast do the compilers themselves run? About 6 minutes.
# Each compiles the same standard kernel, in memory, three times, with the same kernel
# running underneath. Compare results/compilers/table.csv across runs.
# Usage: scripts/bench-compilers.sh LABEL   for example: before, or after-gcc

set -u
export LC_ALL=C
SELF=$(readlink -f "$0")
cd "$(dirname "$SELF")/.." || exit 1

LABEL=${1:-unnamed}
RUNS=3
SOURCE=/usr/src/linux-7.3.1-gentoo
LLVM_BIN=/usr/lib/llvm/22/bin/
CORES=$(nproc)
WORK=/tmp/kiln-compilers-$$
TABLE=results/compilers/table.csv
GOVERNORS=/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
OLD_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

median() { sort -n | awk '{ v[NR] = $1 } END { print v[int((NR + 1) * 0.5)] }'; }
set_governor() { for f in $GOVERNORS; do echo "$1" | sudo tee "$f" >/dev/null; done; }
cleanup() { set_governor "$OLD_GOVERNOR"; rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

mkdir -p "$WORK" results/compilers
set_governor performance

build() {
    for ((i = 0; i < RUNS; i++)); do
        rm -rf "$WORK/kernel"
        make -s -C "$SOURCE" O="$WORK/kernel" "$@" x86_64_defconfig >/dev/null 2>&1
        begin=$(date +%s.%N)
        make -s -C "$SOURCE" O="$WORK/kernel" "$@" -j"$CORES" >/dev/null 2>&1 || echo failed >&2
        end=$(date +%s.%N)
        echo "$begin $end" | awk '{ printf "%.1f\n", $2 - $1 }'
    done | tee -a "$WORK/runs.txt" | median
    rm -rf "$WORK/kernel"
}

echo "Load before starting: $(cut -d' ' -f1-3 /proc/loadavg)"
GCC_S=$(build)
CLANG_S=$(build LLVM="$LLVM_BIN")
GCC_V=$(gcc --version | head -1 | cut -d' ' -f3-5)
CLANG_V=$("${LLVM_BIN}clang" --version | head -1 | cut -d' ' -f3)

[ -e "$TABLE" ] || echo "date,label,kernel,gcc_s,clang_s,gcc_version,clang_version,all_runs" >"$TABLE"
echo "$(date '+%F %H:%M'),$LABEL,$(uname -r),$GCC_S,$CLANG_S,$GCC_V,$CLANG_V,$(paste -sd' ' "$WORK/runs.txt")" >>"$TABLE"
echo "Compile a kernel, median of $RUNS: GCC $GCC_S s, Clang $CLANG_S s"
echo "All runs, GCC then Clang: $(paste -sd' ' "$WORK/runs.txt")"
