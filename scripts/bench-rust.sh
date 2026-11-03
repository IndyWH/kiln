#!/usr/bin/env bash
# Kiln Linux: how fast does the Rust compiler itself run? Under 2 minutes.
# Compiles the same made-up program, in memory, 3 times, with fixed settings, and uses one
# thread for the compile so core placement matters less. Results: results/compilers/rust.csv
# Usage: scripts/bench-rust.sh LABEL   for example: before, or after

set -u
export LC_ALL=C
SELF=$(readlink -f "$0")
cd "$(dirname "$SELF")/.." || exit 1

LABEL=${1:-unnamed}
RUNS=3
WORK=/tmp/kiln-rust-$$
TABLE=results/compilers/rust.csv
mkdir -p "$WORK" results/compilers
trap 'rm -rf "$WORK"' EXIT

awk 'BEGIN {
    print "use std::collections::HashMap;"
    for (i = 0; i < 3000; i++) {
        printf "pub fn f%d(v: &[u64]) -> HashMap<u64, Vec<u64>> {\n", i
        printf "    let mut m = HashMap::new();\n"
        printf "    for (n, x) in v.iter().enumerate() {\n"
        printf "        m.entry(x %% %d).or_insert_with(Vec::new).push(x.wrapping_mul(n as u64 + %d));\n", i + 3, i
        printf "    }\n    m\n}\n"
    }
}' >"$WORK/test.rs"

for ((i = 0; i < RUNS; i++)); do
    begin=$(date +%s.%N)
    taskset -c 0 rustc --edition 2021 --crate-type lib -C opt-level=2 -C codegen-units=1 \
        "$WORK/test.rs" -o "$WORK/test.rlib" 2>"$WORK/errors.txt" || cat "$WORK/errors.txt"
    end=$(date +%s.%N)
    echo "$begin $end" | awk '{ printf "%.2f\n", $2 - $1 }'
done >"$WORK/runs.txt"

MEDIAN=$(sort -n "$WORK/runs.txt" | sed -n 2p)
[ -e "$TABLE" ] || echo "date,label,rustc,median_s,all_runs" >"$TABLE"
echo "$(date '+%F %H:%M'),$LABEL,$(rustc --version | cut -d' ' -f2),$MEDIAN,$(paste -sd' ' "$WORK/runs.txt")" >>"$TABLE"
echo "Rust compile, median of $RUNS: $MEDIAN s. All runs: $(paste -sd' ' "$WORK/runs.txt")"
