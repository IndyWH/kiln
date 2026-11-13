#!/usr/bin/env bash
# Kiln v2: v1's five-program CPU test, run on CachyOS, to compare with v1's Gentoo results.
# Same test files, same work, CPU only, same cores, 5 rounds in a turning order, as
# scripts/cpu-level-run.sh on the stage1-guards branch. See results/cachyos-vs-gentoo/README.md.
#
#   scripts/cachyos-vs-gentoo-build.sh            make both builds first
#   scripts/cachyos-vs-gentoo.sh run PROGRAM [ROUNDS]
#   scripts/cachyos-vs-gentoo.sh same             do the outputs match v1's?
#
# PROGRAM: sqlite, dav1d, lightcraft, darktable or rawtherapee. Builds:
#   cachyos   what Kiln runs: CachyOS's v3 packages; LightCraft and the SQLite test program built
#             with Kiln's v3 makepkg settings, the SQLite test linked to CachyOS's libsqlite3
#   v1recipe  v1's exact build of SQLite, dav1d and LightCraft, made here with Clang 23
# Needs the checked downloads in /tmp/kiln-lab/dl and sources in /tmp/kiln-lab/cachy/src.
# Everything lives in /tmp/kiln-lab/cachy, in memory. Settings of darktable and RawTherapee stay
# there too, never in the owner's home.

set -eu
export LC_ALL=C
LAB=/tmp/kiln-lab/cachy
DL=/tmp/kiln-lab/dl
SRC=$LAB/src
REPO=$(dirname "$(readlink -f "$0")")/..
TABLE=$REPO/results/cachyos-vs-gentoo/runs.csv
RAW=$LAB/data/sony-a7m3-compressed.arw
CLIP=$LAB/data/Chimera-AV1-8bit-1920x1080-6736kbps.ivf
SQLITE_SIZE=400
DAV1D_FRAMES=3000
export LIGHTCRAFT_GPU=0
HOME=$LAB/home
export HOME XDG_CONFIG_HOME=$LAB/home/.config XDG_CACHE_HOME=$LAB/home/.cache
export CARGO_HOME=$LAB/cargo-home
mkdir -p "$HOME"

use_build() { ln -sfn "$LAB/builds/$1" "$LAB/current"; }

builds_for() {
    case $1 in
        sqlite|dav1d|lightcraft) echo "cachyos v1recipe" ;;
        darktable|rawtherapee) echo "cachyos" ;;
        *) echo "unknown program: $1" >&2; exit 1 ;;
    esac
}

# Each develops the raw photo with its default settings, OpenCL off, to a full-size JPEG.
darktable() {
    taskset -c 0-15 /usr/bin/darktable-cli "$RAW" "$1" --apply-custom-presets false --core \
        --configdir "$LAB/home/dt-config" --cachedir "$LAB/home/dt-cache" --library :memory: \
        --disable-opencl >/dev/null 2>&1
}

rawtherapee() {
    taskset -c 0-15 /usr/bin/rawtherapee-cli -o "$1" -d -Y -c "$RAW" >/dev/null 2>&1
}

once() {
    local begin end
    rm -f "$LAB/out.jpg"
    begin=$(date +%s.%N)
    case $1 in
        sqlite) taskset -c 2 /tmp/kiln-lab/cachy/current/bin/speedtest1 --memdb --size "$SQLITE_SIZE" >/dev/null ;;
        dav1d) taskset -c 0-15 /tmp/kiln-lab/cachy/current/bin/dav1d -q -i "$CLIP" --muxer null \
            --threads 16 --limit "$DAV1D_FRAMES" ;;
        lightcraft) taskset -c 0-15 /tmp/kiln-lab/cachy/current/bin/lightcraft-cli render "$RAW" \
            -o "$LAB/out.jpg" >/dev/null ;;
        darktable) darktable "$LAB/out.jpg" ;;
        rawtherapee) rawtherapee "$LAB/out.jpg" ;;
    esac
    end=$(date +%s.%N)
    [ "$1" = sqlite ] || [ "$1" = dav1d ] || [ -s "$LAB/out.jpg" ] || { echo "no picture made" >&2; exit 1; }
    echo "$begin $end" | awk '{ printf "%.3f\n", $2 - $1 }'
}

median() { sort -n | awk '{ a[NR] = $1 } END { print (NR % 2) ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2 }'; }

cmd_run() {
    local program=$1 rounds=${2:-5} round build order
    local -A all
    local builds
    builds=$(builds_for "$program")
    for build in $builds; do use_build "$build"; once "$program" >/dev/null; done  # untimed warm-up
    for round in $(seq 1 "$rounds"); do
        order=$builds
        [ $((round % 2)) = 0 ] && order=$(echo "$builds" | tr ' ' '\n' | tac | tr '\n' ' ')
        for build in $order; do
            use_build "$build"
            all[$build]+="$(once "$program") "
        done
    done
    [ -e "$TABLE" ] || echo "date,program,build,median_s,runs,kernel" >"$TABLE"
    for build in $builds; do
        local times=${all[$build]% } m
        m=$(echo "$times" | tr ' ' '\n' | median)
        echo "$(date '+%F %H:%M'),$program,$build,$m,$times,$(uname -r)" >>"$TABLE"
        echo "$program $build: median $m s ($times)"
    done
}

cmd_same() {
    # v1's outputs on Gentoo: dav1d 5dc6df32af29d714a1f37f61729a4a6e, LightCraft 980a227c7f528843.
    local build
    for build in cachyos v1recipe; do
        use_build "$build"
        echo "dav1d $build: $(/tmp/kiln-lab/cachy/current/bin/dav1d -q -i "$CLIP" --muxer md5 \
            --limit 300 -o - 2>/dev/null)"
        /tmp/kiln-lab/cachy/current/bin/lightcraft-cli render "$RAW" -o "$LAB/out-$build.jpg" >/dev/null
        echo "lightcraft $build: $(sha256sum "$LAB/out-$build.jpg" | cut -c1-16)"
    done
}

command=${1:?run or same}; shift
case $command in
    run) cmd_run "$@" ;;
    same) cmd_same ;;
    *) echo "unknown command: $command"; exit 1 ;;
esac
