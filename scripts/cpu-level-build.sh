#!/usr/bin/env bash
# Kiln Linux: the CPU setting test, part 1 of 2, the builds. The same programs, built with the same
# compiler and flags, except the CPU setting: generic x86-64, x86-64-v3 or native. Kiln's normal
# flags otherwise, from make.conf: -O2 -pipe for C, opt-level 3 and one codegen unit for Rust.
# Predictions: docs/HYPOTHESES.md, 5 Nov 2026. Timing: scripts/cpu-level-run.sh.
# Everything happens in /tmp/kiln-lab/cpu, in memory, so a restart empties it. It installs nothing
# and needs no root. Downloads are checked against the checksums below before use.
#
#   scripts/cpu-level-build.sh setup                  unpack the checked downloads, fetch crates
#   scripts/cpu-level-build.sh build PROGRAM LEVEL    PROGRAM: sqlite, dav1d or lightcraft
#   scripts/cpu-level-build.sh check PROGRAM LEVEL    count the wide (AVX) instructions in it
#   scripts/cpu-level-build.sh all                    every program at every level, then check
#
# LEVEL: generic, v3 or native. Each build ends in /tmp/kiln-lab/cpu/builds/LEVEL/bin.

set -eu
export LC_ALL=C
LAB=/tmp/kiln-lab/cpu
DL=/tmp/kiln-lab/dl
SRC=$LAB/src
CLANG=/usr/lib/llvm/22/bin/clang
OBJDUMP=/usr/lib/llvm/22/bin/llvm-objdump
LEVELS="generic v3 native"
PROGRAMS="sqlite dav1d lightcraft"

# File, SHA-256. The raw photo's sum is LightCraft's own (xtask/src/raw_samples.rs), dav1d's is
# VideoLAN's, SQLite's source matched Gentoo's Manifest. SQLite's single file, sqlite3.c, has the
# same source ID as that source's manifest.uuid, bf7c7f30. LightCraft's and the clip's were taken on
# 11 Nov 2026. The single file is used as SQLite's ./configure cannot be checked by the disk guard
# before it is unpacked. Sources:
#   github.com/storytold/lightcraft/archive/refs/tags/v0.18.1.tar.gz
#   downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz
#   sqlite.org/2026/sqlite-src-3530400.zip
#   raw.pixls.us/getfile.php/2414 (CC0)
#   s3.amazonaws.com/download.opencontent.netflix.com/AV1/Chimera/Old/ (Netflix Open Content)
SUMS="
lightcraft/lightcraft-0.18.1.tar.gz da592ba01b21c8a281067e223826b62e3988a0c93032297c9b23e7b8fb844baa
dav1d/dav1d-1.5.4.tar.xz 686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5
sqlite/sqlite-src-3530400.zip d18fa15aec74d8c17e1463f861095adc01b5ad190256acb4f91d22f0368d232b
sqlite/sqlite-amalgamation-3530400.zip 1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d
raw/sony-a7m3-compressed.arw 250784580ea527442c09004417bb0eead484f2bf3ee8f9121a776ac65bb50d0f
av1/Chimera-AV1-8bit-1920x1080-6736kbps.ivf 49117ca3e34c8572b16a66fb1a3e23aed7e71e63cbb6ec8f3b85ef53e9e2f2d1
"

cflags() {
    case $1 in
        generic) echo "-O2 -pipe -march=x86-64" ;;
        v3) echo "-O2 -pipe -march=x86-64-v3" ;;
        native) echo "-O2 -pipe -march=native" ;;
        *) echo "unknown level: $1" >&2; exit 1 ;;
    esac
}

rustflags() {
    case $1 in
        generic) echo "-C target-cpu=x86-64 -C opt-level=3 -C codegen-units=1" ;;
        v3) echo "-C target-cpu=x86-64-v3 -C opt-level=3 -C codegen-units=1" ;;
        native) echo "-C target-cpu=native -C opt-level=3 -C codegen-units=1" ;;
        *) echo "unknown level: $1" >&2; exit 1 ;;
    esac
}

cmd_setup() {
    local file sum
    echo "$SUMS" | while read -r file sum; do
        [ -n "$file" ] || continue
        [ -f "$DL/$file" ] || { echo "missing download: $DL/$file"; exit 1; }
        echo "$sum  $DL/$file" | sha256sum -c --quiet
    done
    rm -rf "$SRC"
    mkdir -p "$SRC" "$LAB/data"
    tar -xzf "$DL/lightcraft/lightcraft-0.18.1.tar.gz" -C "$SRC"
    tar -xJf "$DL/dav1d/dav1d-1.5.4.tar.xz" -C "$SRC"
    unzip -q "$DL/sqlite/sqlite-src-3530400.zip" -d "$SRC"
    unzip -q "$DL/sqlite/sqlite-amalgamation-3530400.zip" -d "$SRC"
    cp "$DL/raw/sony-a7m3-compressed.arw" "$DL/av1/Chimera-AV1-8bit-1920x1080-6736kbps.ivf" "$LAB/data/"
    # LightCraft's crates, fetched once, so the builds run offline and alike.
    (cd "$SRC/lightcraft-0.18.1" && CARGO_HOME="$LAB/cargo-home" cargo fetch --locked)
    echo "setup done"
}

build_sqlite() {
    local level=$1 out=$2 a=$SRC/sqlite-amalgamation-3530400
    # speedtest1 is SQLite's own speed test, from the full source. Threads off, as it uses one.
    # R-Tree on, as in Gentoo's SQLite: the test's default mix stops without it.
    $CLANG $(cflags "$level") -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_ENABLE_RTREE -I"$a" \
        -o "$out/bin/speedtest1" "$SRC/sqlite-src-3530400/test/speedtest1.c" "$a/sqlite3.c" -lm
}

build_dav1d() {
    local level=$1 out=$2
    # Gentoo's way: buildtype plain, so the flags are only ours. Assembly stays on, as in Gentoo:
    # dav1d chooses its hand-written code for the CPU at run time, whatever the setting.
    rm -rf "$out/dav1d-build"
    CC=$CLANG CFLAGS="$(cflags "$level")" meson setup "$out/dav1d-build" "$SRC/dav1d-1.5.4" \
        --buildtype=plain -Ddefault_library=static -Denable_tools=true -Denable_tests=false >/dev/null
    ninja -C "$out/dav1d-build" >/dev/null
    cp "$out/dav1d-build/tools/dav1d" "$out/bin/dav1d"
}

build_lightcraft() {
    local level=$1 out=$2
    # CARGO_ENCODED_RUSTFLAGS must be unset, not empty, or cargo ignores RUSTFLAGS without saying so.
    (cd "$SRC/lightcraft-0.18.1" && unset CARGO_ENCODED_RUSTFLAGS && \
        CARGO_HOME="$LAB/cargo-home" CARGO_TARGET_DIR="$out/lightcraft-target" \
        CC=$CLANG CFLAGS="$(cflags "$level")" RUSTFLAGS="$(rustflags "$level")" \
        cargo build --offline --locked --release -p lightcraft-cli -j32)
    cp "$out/lightcraft-target/release/lightcraft-cli" "$out/bin/lightcraft-cli"
}

cmd_build() {
    local program=$1 level=$2 out=$LAB/builds/$2 begin end
    cflags "$level" >/dev/null
    mkdir -p "$out/bin"
    begin=$(date +%s)
    case $program in
        sqlite) build_sqlite "$level" "$out" ;;
        dav1d) build_dav1d "$level" "$out" ;;
        lightcraft) build_lightcraft "$level" "$out" ;;
        *) echo "unknown program: $program"; exit 1 ;;
    esac
    end=$(date +%s)
    echo "built $program $level in $((end - begin)) s"
}

cmd_check() {
    # AVX2 uses ymm registers, AVX-512 zmm. Generic x86-64 code should have no ymm of its own, so
    # any found there are the program's hand-written code. Proves the setting reached the build.
    local program=$1 level=$2 file ymm zmm
    case $program in
        sqlite) file=speedtest1 ;; dav1d) file=dav1d ;; lightcraft) file=lightcraft-cli ;;
        *) echo "unknown program: $program"; exit 1 ;;
    esac
    file=$LAB/builds/$level/bin/$file
    ymm=$($OBJDUMP -d --no-show-raw-insn "$file" | grep -c '%ymm' || true)
    zmm=$($OBJDUMP -d --no-show-raw-insn "$file" | grep -c '%zmm' || true)
    echo "$program $level: $ymm instructions with ymm (AVX2), $zmm with zmm (AVX-512)"
}

cmd_all() {
    local program level
    for program in $PROGRAMS; do
        for level in $LEVELS; do cmd_build "$program" "$level"; done
    done
    for program in $PROGRAMS; do
        for level in $LEVELS; do cmd_check "$program" "$level"; done
    done
}

command=${1:?setup, build, check or all}; shift
case $command in
    setup) cmd_setup ;;
    build) cmd_build "$@" ;;
    check) cmd_check "$@" ;;
    all) cmd_all ;;
    *) echo "unknown command: $command"; exit 1 ;;
esac
