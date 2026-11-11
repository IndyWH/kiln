#!/usr/bin/env bash
# Kiln Linux: the CPU setting test, part 2 of 2, the timing. Times the same work on each build made
# by scripts/cpu-level-build.sh, CPU only: LightCraft with its GPU use off, dav1d and SQLite have none.
# Results: results/cpu-level/runs.csv. Predictions: docs/HYPOTHESES.md, 5 Nov 2026.
#
#   scripts/cpu-level-run.sh PROGRAM [ROUNDS] [NOTE]    PROGRAM: sqlite, dav1d or lightcraft
#   scripts/cpu-level-run.sh same                       do the three builds give the same output?
#
# Each round times every level once, in a turning order, so drift does not favour one level. One
# P-core (CPU 2) for SQLite, which uses one thread. The 8 P-cores and their twins (CPUs 0 to 15) for
# the others, so the slower E-cores do not add noise. The disk guard checks each program this
# script runs before it starts, so they are full paths through a link, current, which must exist:
# build everything first.

set -eu
export LC_ALL=C
LAB=/tmp/kiln-lab/cpu
REPO=$(dirname "$(readlink -f "$0")")/..
TABLE=$REPO/results/cpu-level/runs.csv
RAW=$LAB/data/sony-a7m3-compressed.arw
CLIP=$LAB/data/Chimera-AV1-8bit-1920x1080-6736kbps.ivf
SQLITE_SIZE=400
DAV1D_FRAMES=3000
export LIGHTCRAFT_GPU=0

use_level() { ln -sfn "$LAB/builds/$1" "$LAB/current"; }

once() {
    # $1: program. Prints the seconds for one run of the build that current points to.
    local begin end
    begin=$(date +%s.%N)
    case $1 in
        sqlite) taskset -c 2 /tmp/kiln-lab/cpu/current/bin/speedtest1 --memdb --size "$SQLITE_SIZE" >/dev/null ;;
        dav1d) taskset -c 0-15 /tmp/kiln-lab/cpu/current/bin/dav1d -q -i "$CLIP" --muxer null \
            --threads 16 --limit "$DAV1D_FRAMES" ;;
        lightcraft) taskset -c 0-15 /tmp/kiln-lab/cpu/current/bin/lightcraft-cli render "$RAW" \
            -o "$LAB/out.jpg" >/dev/null ;;
        *) echo "unknown program: $1" >&2; exit 1 ;;
    esac
    end=$(date +%s.%N)
    echo "$begin $end" | awk '{ printf "%.3f\n", $2 - $1 }'
}

median() { sort -n | awk '{ a[NR] = $1 } END { print (NR % 2) ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2 }'; }

cmd_run() {
    local program=$1 rounds=${2:-5} note=${3:-} round level order times
    local -A all
    # One untimed run each first, so files are in memory and the CPU is awake.
    for level in generic v3 native; do use_level "$level"; once "$program" >/dev/null; done
    for round in $(seq 1 "$rounds"); do
        case $((round % 3)) in
            1) order="generic v3 native" ;; 2) order="v3 native generic" ;; 0) order="native generic v3" ;;
        esac
        for level in $order; do
            use_level "$level"
            all[$level]+="$(once "$program") "
        done
    done
    mkdir -p "$(dirname "$TABLE")"
    [ -e "$TABLE" ] || echo "date,program,level,median_s,runs,note" >"$TABLE"
    local base=""
    for level in generic v3 native; do
        times=${all[$level]% }
        local m
        m=$(echo "$times" | tr ' ' '\n' | median)
        [ -n "$base" ] || base=$m
        echo "$(date '+%F %H:%M'),$program,$level,$m,$times,$note" >>"$TABLE"
        echo "$program $level: median $m s ($times)" \
            "$(echo "$base $m" | awk '{ printf "%+.1f%% time against generic", ($2 - $1) / $1 * 100 }')"
    done
}

cmd_same() {
    # dav1d's md5 of every decoded frame, and LightCraft's output file, per level.
    local level
    for level in generic v3 native; do
        use_level "$level"
        echo "dav1d $level: $(/tmp/kiln-lab/cpu/current/bin/dav1d -q -i "$CLIP" --muxer md5 \
            --limit 300 -o - 2>/dev/null)"
        /tmp/kiln-lab/cpu/current/bin/lightcraft-cli render "$RAW" -o "$LAB/out-$level.jpg" >/dev/null
        echo "lightcraft $level: $(sha256sum "$LAB/out-$level.jpg" | cut -c1-16)"
    done
}

command=${1:?sqlite, dav1d, lightcraft or same}; shift
case $command in
    sqlite|dav1d|lightcraft) cmd_run "$command" "$@" ;;
    same) cmd_same ;;
    *) echo "unknown command: $command"; exit 1 ;;
esac
