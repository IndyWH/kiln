#!/usr/bin/env bash
# Kiln v2: builds for scripts/cachyos-vs-gentoo.sh, which times them. Two scripts, because the
# disk guard checks every program a script runs before it starts, so they must exist first.
#
#   scripts/cachyos-vs-gentoo-build.sh
#
# Builds, in /tmp/kiln-lab/cachy/builds:
#   cachyos   what Kiln runs: CachyOS's dav1d package; LightCraft and SQLite's test program built
#             with Kiln's v3 makepkg settings, the SQLite test linked to CachyOS's libsqlite3
#   v1recipe  v1's exact build of SQLite, dav1d and LightCraft, made here with Clang 23
# Needs the checked downloads in /tmp/kiln-lab/dl and sources in /tmp/kiln-lab/cachy/src.

set -eu
export LC_ALL=C
LAB=/tmp/kiln-lab/cachy
DL=/tmp/kiln-lab/dl
SRC=$LAB/src
export CARGO_HOME=$LAB/cargo-home

# Kiln's v3 makepkg settings: CachyOS's /etc/makepkg.conf with zz-kiln-x86-64-v3.conf on top.
KILN_CFLAGS="-march=x86-64-v3 -O3 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat \
-Werror=format-security -fstack-clash-protection -fcf-protection"
KILN_LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs"
KILN_RUSTFLAGS="-C opt-level=3 -C target-cpu=x86-64-v3"
# v1's: make.conf's -O2 -pipe, Clang, and for Rust opt-level 3 with one codegen unit.
V1_CFLAGS="-O2 -pipe -march=x86-64-v3"
V1_RUSTFLAGS="-C target-cpu=x86-64-v3 -C opt-level=3 -C codegen-units=1"

build_cachyos() {
    local out=$LAB/builds/cachyos
    mkdir -p "$out/bin"
    ln -sfn /usr/bin/dav1d "$out/bin/dav1d"
    # -DSQLITE_ENABLE_RTREE only tells the test program to run its R-Tree part; the library has it.
    gcc $KILN_CFLAGS $KILN_LDFLAGS -DSQLITE_ENABLE_RTREE -o "$out/bin/speedtest1" \
        "$SRC/sqlite-src-3530400/test/speedtest1.c" -lsqlite3 -lm
    (cd "$SRC/lightcraft-0.18.1" && unset CARGO_ENCODED_RUSTFLAGS &&
        CARGO_TARGET_DIR="$out/lightcraft-target" CFLAGS="$KILN_CFLAGS" CXXFLAGS="$KILN_CFLAGS" \
        RUSTFLAGS="$KILN_RUSTFLAGS" cargo build --offline --locked --release -p lightcraft-cli -j32)
    cp "$out/lightcraft-target/release/lightcraft-cli" "$out/bin/lightcraft-cli"
}

build_v1recipe() {
    local out=$LAB/builds/v1recipe a=$SRC/sqlite-amalgamation-3530400
    mkdir -p "$out/bin"
    clang $V1_CFLAGS -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_ENABLE_RTREE -I"$a" \
        -o "$out/bin/speedtest1" "$SRC/sqlite-src-3530400/test/speedtest1.c" "$a/sqlite3.c" -lm
    rm -rf "$out/dav1d-build"
    CC=clang CFLAGS="$V1_CFLAGS" meson setup "$out/dav1d-build" "$SRC/dav1d-1.5.4" \
        --buildtype=plain -Ddefault_library=static -Denable_tools=true -Denable_tests=false >/dev/null
    ninja -C "$out/dav1d-build" >/dev/null
    cp "$out/dav1d-build/tools/dav1d" "$out/bin/dav1d"
    (cd "$SRC/lightcraft-0.18.1" && unset CARGO_ENCODED_RUSTFLAGS &&
        CARGO_TARGET_DIR="$out/lightcraft-target" CC=clang CFLAGS="$V1_CFLAGS" \
        RUSTFLAGS="$V1_RUSTFLAGS" cargo build --offline --locked --release -p lightcraft-cli -j32)
    cp "$out/lightcraft-target/release/lightcraft-cli" "$out/bin/lightcraft-cli"
}

main() {
    unzip -q -o "$DL/sqlite/sqlite-amalgamation-3530400.zip" -d "$SRC"
    [ -d "$SRC/dav1d-1.5.4" ] || tar -xJf "$DL/dav1d/dav1d-1.5.4.tar.xz" -C "$SRC"
    (cd "$SRC/lightcraft-0.18.1" && cargo fetch --locked)
    local begin=$(date +%s)
    build_cachyos
    echo "built cachyos in $(($(date +%s) - begin)) s"
    begin=$(date +%s)
    build_v1recipe
    echo "built v1recipe in $(($(date +%s) - begin)) s"
}

main
