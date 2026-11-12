#!/usr/bin/env bash
# Kiln Linux: compile speed of our Rust against rust-bin, on a real program kept out of all
# training: LightCraft 0.18.1 (lightcraft-cli). Its own debug and release settings, no extra
# flags, all cores. The same cargo (rust-bin's) for both; only the compiler changes. Builds take
# turns, rust-bin then ours, so drift does not favour one. Results: results/rust-gap/lightcraft.csv.
# Needs the source and crates from scripts/cpu-level-build.sh setup.
#
#   scripts/lightcraft-compile.sh [ROUNDS] [NOTE]

set -eu
export LC_ALL=C
LAB=/tmp/kiln-lab/cpu
SOURCE=$LAB/src/lightcraft-0.18.1
TARGET=/tmp/kiln-lab/lc-compile-target
OURS=/usr/lib/rust/1.98.1/bin/rustc
OFFICIAL=/opt/rust-bin-1.98.1/bin/rustc
REPO=$(dirname "$(readlink -f "$0")")/..
TABLE=$REPO/results/rust-gap/lightcraft.csv

once() {
    # $1: compiler, $2: empty for debug, or --release. Prints the seconds for a full clean build.
    local begin end
    rm -rf "$TARGET"
    begin=$(date +%s.%N)
    # CARGO_ENCODED_RUSTFLAGS must be unset, not empty, or cargo ignores RUSTFLAGS without saying so.
    (cd "$SOURCE" && unset CARGO_ENCODED_RUSTFLAGS RUSTFLAGS && RUSTC=$1 CARGO_HOME="$LAB/cargo-home" \
        CARGO_TARGET_DIR="$TARGET" \
        /opt/rust-bin-1.98.1/bin/cargo build --offline --locked $2 -p lightcraft-cli -j32 >/dev/null 2>&1)
    end=$(date +%s.%N)
    rm -rf "$TARGET"
    echo "$begin $end" | awk '{ printf "%.2f\n", $2 - $1 }'
}

median() { sort -n | awk '{ a[NR] = $1 } END { print (NR % 2) ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2 }'; }

rounds=${1:-3} note=${2:-}
"$OURS" --version >/dev/null && "$OFFICIAL" --version >/dev/null
mkdir -p "$(dirname "$TABLE")"
[ -e "$TABLE" ] || echo "date,kind,ours_median_s,ours_runs,rust_bin_median_s,rust_bin_runs,note" >"$TABLE"
for kind in debug release; do
    option=""
    [ "$kind" = release ] && option=--release
    ours="" official=""
    for round in $(seq 1 "$rounds"); do
        official+="$(once "$OFFICIAL" "$option") "
        ours+="$(once "$OURS" "$option") "
    done
    ours=${ours% } official=${official% }
    m1=$(echo "$ours" | tr ' ' '\n' | median)
    m2=$(echo "$official" | tr ' ' '\n' | median)
    echo "$(date '+%F %H:%M'),$kind,$m1,$ours,$m2,$official,$note" >>"$TABLE"
    echo "lightcraft $kind: ours $m1 s ($ours), rust-bin $m2 s ($official)" \
        "$(echo "$m2 $m1" | awk '{ printf "%+.1f%% time against rust-bin", ($2 - $1) / $1 * 100 }')"
done
