#!/usr/bin/env bash
# Kiln Linux: why is our Rust compiler slower than rust-bin? The gap is all in libLLVM, so this
# rebuilds only libLLVM and drops it in beside our own rustc, in a throwaway folder in memory.
# It installs nothing, and needs no root.
#
#   KILN_LAB=/path scripts/rust-llvm-lab.sh build NAME [lto=none|thin|full] [instr=1] [profile=FILE]
#                                                       [flags="-extra"] [cpu="-march=native"]
#                                                       [static=1] [relocs=1]
#   KILN_LAB=/path scripts/rust-llvm-lab.sh train NAME PROFILE_OUT
#   KILN_LAB=/path scripts/rust-llvm-lab.sh bolt NAME SOURCE
#   KILN_LAB=/path scripts/rust-llvm-lab.sh bench NAME [NOTE]
#
# Results: results/rust-gap/runs.csv. Each bench times rust-bin before and after, as the control.
# The disk guard checks each program this script runs, so they are written as full paths, and a
# link, lab/current, chooses which rustc runs. The lab path below is one session's scratch folder.

set -eu
export LC_ALL=C
SELF=$(readlink -f "$0")
REPO=$(dirname "$SELF")/..
LAB=${KILN_LAB:?set KILN_LAB}

BIN=/usr/lib/llvm/22/bin
RUSTSRC=$LAB/src/rustc-1.98.1-src
LLVMSRC=$RUSTSRC/src/llvm-project/llvm
OURS=/usr/lib/rust/1.98.1
OFFICIAL=/opt/rust-bin-1.98.1
LIBNAME=libLLVM.so.22.1-rust-1.98.1-stable
TABLE=$REPO/results/rust-gap/runs.csv
TOOLS=$LAB/builds/tools/bin

use_rustc() { ln -sfn "$1" "$LAB/current"; }

# rustc with the given libLLVM. The driver, standard library and rustc itself stay ours.
make_mix() {
    local name=$1 lib=$2 mix=$LAB/mix/$1
    rm -rf "$mix"
    mkdir -p "$mix/bin" "$mix/lib"
    cp "$OURS/bin/rustc" "$mix/bin/"
    cp "$OURS"/lib/librustc_driver-*.so "$mix/lib/"
    cp "$lib" "$mix/lib/$LIBNAME"
    ln -s "$OURS/lib/rustlib" "$mix/lib/rustlib"
    use_rustc "$mix"
    /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/current/bin/rustc -vV | sed -n '1p;$p'
}

cmd_tools() {
    # The build's own helper programs, built once, so each variant need not rebuild them.
    [ -x "$TOOLS/llvm-tblgen" ] && return 0
    cmake -G Ninja -S "$LLVMSRC" -B "$LAB/builds/tools" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$BIN/clang" -DCMAKE_CXX_COMPILER="$BIN/clang++" \
        -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_BINDINGS=OFF >/dev/null
    nice -n 10 ninja -C "$LAB/builds/tools" llvm-tblgen llvm-min-tblgen >/dev/null
}

cmd_build() {
    local name=$1; shift
    local lto=none instr=0 profile="" flags="" cpu="-march=native" static=0 relocs=0 arg
    for arg in "$@"; do
        case $arg in
            lto=*) lto=${arg#*=} ;;
            instr=*) instr=${arg#*=} ;;
            profile=*) profile=${arg#*=} ;;
            flags=*) flags=${arg#*=} ;;
            cpu=*) cpu=${arg#*=} ;;
            static=*) static=${arg#*=} ;;
            relocs=*) relocs=${arg#*=} ;;
            *) echo "unknown setting: $arg"; exit 1 ;;
        esac
    done
    cmd_tools
    local out=$LAB/builds/$name begin=$SECONDS
    # The same flags as the real build: see config/portage/env/rust-compiler-overfire.conf.
    local cf="-O3 -pipe $cpu $flags"
    local ld="-Wl,-O1 -Wl,--as-needed -Wl,-z,pack-relative-relocs -fuse-ld=lld"
    # For BOLT: link as the official build does. With compact relocations and immediate binding,
    # the BOLT-instrumented library crashed here.
    [ "$relocs" = 1 ] && ld="-Wl,-O1 -Wl,--as-needed -fuse-ld=lld -Wl,-z,lazy -Wl,-q"
    [ "$static" = 1 ] && ld="$ld -Wl,-Bsymbolic -static-libstdc++"
    [ "$static" = symbolic ] && ld="$ld -Wl,-Bsymbolic"
    local -a extra=()
    case $lto in
        none) ;;
        thin) extra+=(-DLLVM_ENABLE_LTO=Thin -DLLVM_ENABLE_LLD=ON) ;;
        full) extra+=(-DLLVM_ENABLE_LTO=Full -DLLVM_ENABLE_LLD=ON) ;;
        *) echo "unknown lto: $lto"; exit 1 ;;
    esac
    [ "$instr" = 1 ] && extra+=(-DLLVM_BUILD_INSTRUMENTED=IR -DLLVM_BUILD_RUNTIME=No)
    [ -n "$profile" ] && extra+=(-DLLVM_PROFDATA_FILE="$profile")
    rm -rf "$out"
    # Settings from src/bootstrap/src/core/build_steps/llvm.rs, and Gentoo's X86 only target.
    cmake -G Ninja -S "$LLVMSRC" -B "$out" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$BIN/clang" -DCMAKE_CXX_COMPILER="$BIN/clang++" \
        -DCMAKE_AR="$BIN/llvm-ar" -DCMAKE_NM="$BIN/llvm-nm" -DCMAKE_RANLIB="$BIN/llvm-ranlib" \
        -DCMAKE_C_FLAGS="$cf" -DCMAKE_CXX_FLAGS="$cf" \
        -DCMAKE_SHARED_LINKER_FLAGS="$ld" -DCMAKE_EXE_LINKER_FLAGS="$ld" -DCMAKE_MODULE_LINKER_FLAGS="$ld" \
        -DLLVM_NATIVE_TOOL_DIR="$TOOLS" \
        -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_UNREACHABLE_OPTIMIZE=OFF -DLLVM_ENABLE_PLUGINS=OFF \
        -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD= \
        -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_BINDINGS=OFF \
        -DLLVM_ENABLE_Z3_SOLVER=OFF -DLLVM_TARGET_ARCH=x86_64 \
        -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-gnu -DLLVM_ENABLE_WARNINGS=OFF \
        -DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_ZLIB=ON -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_VERSION_SUFFIX=-rust-1.98.1-stable "${extra[@]}" >/dev/null
    nice -n 10 ninja -C "$out" LLVM >/dev/null
    make_mix "$name" "$out/lib/$LIBNAME"
    echo "built $name in $((SECONDS - begin)) s: $(stat -c %s "$out/lib/$LIBNAME") bytes. CFLAGS: $cf  LDFLAGS: $ld  ${extra[*]:-}"
}

run_training() {
    # The same training as config/portage/env/dev-lang/rust: made-up code, then cargo.
    local name=$1 work=$LAB/train/$1 level profile
    use_rustc "$LAB/mix/$name"
    rm -rf "$work"
    mkdir -p "$work"
    awk 'BEGIN { print "use std::collections::HashMap;"
        for (i = 0; i < 1500; i++) {
            printf "pub fn f%d(v: &[u64]) -> HashMap<u64, Vec<u64>> { let mut m = HashMap::new();", i
            printf " for (n, x) in v.iter().enumerate() { m.entry(x %% %d).or_insert_with(Vec::new)", i + 3
            printf ".push(x.wrapping_mul(n as u64 + %d)); } m }\n", i } }' >"$work/made-up.rs"
    for level in 0 2 3; do
        /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/current/bin/rustc --edition 2021 --crate-type lib -C opt-level="$level" -C codegen-units=1 \
            "$work/made-up.rs" -o "$work/made-up-$level.rlib"
    done
    for profile in "" --release; do
        (cd "$RUSTSRC" && RUSTC="$LAB/current/bin/rustc" CARGO_HOME="$work/cargo-home" CARGO_TARGET_DIR="$work/target$profile" \
            RUSTC_BOOTSTRAP=1 RUSTFLAGS="" CARGO_ENCODED_RUSTFLAGS="" \
            /opt/rust-bin-1.98.1/bin/cargo build --offline --locked $profile \
            --manifest-path src/tools/cargo/Cargo.toml -j"${TRAIN_JOBS:-32}" >/dev/null 2>&1)
    done
    rm -rf "$work"
}

cmd_train() {
    local name=$1 out=$2 raw=$LAB/raw/$1
    rm -rf "$raw"
    mkdir -p "$raw"
    export LLVM_PROFILE_FILE="$raw/default_%m_%p.profraw"
    run_training "$name"
    unset LLVM_PROFILE_FILE
    /usr/lib/llvm/22/bin/llvm-profdata merge -o "$out" "$raw"/*.profraw
    rm -rf "$raw"
    /usr/lib/llvm/22/bin/llvm-profdata show "$out" | grep -E 'Total functions|Maximum function count|Instrumentation'
}

cmd_bolt() {
    # BOLT with the official build's settings, from src/tools/opt-dist/src/bolt.rs. SOURCE must be
    # built with relocs=1. Trains on the same work as PGO.
    local name=$1 source=$2 prof=$LAB/raw/$1 input output
    input=$LAB/builds/$source/lib/$LIBNAME
    output=$LAB/builds/$name.so
    rm -rf "$prof"
    mkdir -p "$prof"
    /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/builds/bolt/bin/llvm-bolt -instrument "$input" \
        --instrumentation-file="$prof/prof.fdata" --instrumentation-file-append-pid -o "$output.instr"
    make_mix "$name-instr" "$output.instr"
    # Each process writes its own large file, and they filled 30 GB of memory, so merge as we go.
    merge_finished() {
        local files
        files=$(find "$prof" -name 'prof.fdata.*' -mmin "$1")
        [ -n "$files" ] || return 0
        [ -e "$prof/merged" ] && files="$files $prof/merged"
        /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/builds/bolt/bin/merge-fdata $files >"$prof/merged.new"
        rm -f $files
        mv "$prof/merged.new" "$prof/merged"
    }
    (while :; do merge_finished +0.2; sleep 20; done) &
    local merger=$!
    TRAIN_JOBS=12 run_training "$name-instr"
    kill "$merger"
    wait "$merger" 2>/dev/null || true
    merge_finished -9999
    mv "$prof/merged" "$LAB/$name.fdata"
    ls -la "$LAB/$name.fdata"
    rm -rf "$prof" "$LAB/mix/$name-instr" "$output.instr"
    /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/builds/bolt/bin/llvm-bolt "$input" -data "$LAB/$name.fdata" -o "$output" \
        -reorder-blocks=ext-tsp -reorder-functions=cdsort -split-functions -split-strategy=cdsplit \
        -split-all-cold -jump-tables=move -icf=all -dyno-stats 2>&1 | tail -25
    make_mix "$name" "$output"
}

time_it() {
    # Prints the seconds for one run on one core, of the rustc that lab/current points to.
    local begin end
    begin=$(date +%s.%N)
    taskset -c 0 /tmp/claude-1000/-home-indy-Projects-kiln/6a15672e-16e5-40c8-845a-ba4a31143835/scratchpad/lab/current/bin/rustc --edition 2021 --crate-type lib -C opt-level=2 -C codegen-units=1 \
        "$LAB/bench.rs" -o "$LAB/bench.rlib"
    end=$(date +%s.%N)
    echo "$begin $end" | awk '{ printf "%.2f\n", $2 - $1 }'
}

median_of_3() { sort -n | sed -n 2p; }

cmd_bench() {
    local name=$1 note=${2:-} tree=$LAB/mix/$1 a b c1 c2 runs median
    [ "$name" = ours ] && tree=$OURS
    [ -e "$LAB/bench.rs" ] || awk 'BEGIN { print "use std::collections::HashMap;"
        for (i = 0; i < 3000; i++) {
            printf "pub fn f%d(v: &[u64]) -> HashMap<u64, Vec<u64>> {\n", i
            printf "    let mut m = HashMap::new();\n"
            printf "    for (n, x) in v.iter().enumerate() {\n"
            printf "        m.entry(x %% %d).or_insert_with(Vec::new).push(x.wrapping_mul(n as u64 + %d));\n", i + 3, i
            printf "    }\n    m\n}\n" } }' >"$LAB/bench.rs"
    use_rustc "$OFFICIAL"; c1=$(time_it)
    use_rustc "$tree"; runs=$(for a in 1 2 3; do time_it; done)
    use_rustc "$OFFICIAL"; c2=$(time_it)
    median=$(echo "$runs" | median_of_3)
    b=$(echo "$runs" | paste -sd' ')
    mkdir -p "$(dirname "$TABLE")"
    [ -e "$TABLE" ] || echo "date,name,median_s,runs,rust_bin_before,rust_bin_after,note" >"$TABLE"
    echo "$(date '+%F %H:%M'),$name,$median,$b,$c1,$c2,$note" >>"$TABLE"
    echo "$name: median $median s ($b). rust-bin: $c1 then $c2. $note"
}

command=${1:?build, train or bench}; shift
case $command in
    build) cmd_build "$@" ;;
    train) cmd_train "$@" ;;
    bolt) cmd_bolt "$@" ;;
    adopt) make_mix "$1" "$2" ;;
    bench) cmd_bench "$@" ;;
    *) echo "unknown command: $command"; exit 1 ;;
esac
