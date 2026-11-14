#!/usr/bin/env bash
# Tests of kernel/rebuild.sh up to its review step, in a throwaway cache. Builds and installs
# nothing. Needs the real cache seeded (kernel/rebuild.sh seed) and the network.
#   bash tests/kernel/test_rebuild.sh        (from the repo folder)
# Each case makes a last good kernel and its profiles' fingerprint from the same old files.
set -uo pipefail
REAL=$HOME/.cache/kiln-kernel
T=$(mktemp -d)
UPG="git -C $REAL/upstream"
pass=0 fail=0
expect() {  # what text
    if grep -qF -- "$2" "$T/out"; then pass=$((pass + 1)); echo "  ok: $1"
    else fail=$((fail + 1)); echo "  FAIL: $1 (wanted: $2)"; sed 's/^/    | /' "$T/out" | head -12; fi
}

setup() {  # last good made from upstream commit $1, its PKGBUILD edited by sed $2, its config by sed $3
    rm -rf "$T"; mkdir -p "$T/last-good" "$T/profiles/current" "$T/rebuild" "$T/fp"
    ln -s "$REAL/upstream" "$T/upstream"
    cp -r "$REAL/rebuild/reviewed" "$T/rebuild/"
    $UPG show "$1:linux-cachyos/PKGBUILD" > "$T/last-good/PKGBUILD.cachyos"
    $UPG show "$1:linux-cachyos/config" > "$T/last-good/config"
    [ -z "${2:-}" ] || sed -i "$2" "$T/last-good/PKGBUILD.cachyos"
    [ -z "${3:-}" ] || sed -i "$3" "$T/last-good/config"
    cp kernel/PKGBUILD "$T/last-good/PKGBUILD"
    $UPG rev-parse "$1" > "$T/last-good/upstream-commit"
    cp "$T/last-good/PKGBUILD.cachyos" "$T/last-good/config" "$T/fp/"
    b2sum "$REAL/rebuild/reviewed/0001-bore-cachy.patch" | cut -d' ' -f1 > "$T/fp/bore.b2sum"
    KILN_KERNEL_CACHE=$T kernel/rebuild.sh fingerprint "$T/fp" > "$T/profiles/current/fingerprint"
    for p in linux-cachyos-kiln linux-cachyos-kiln-dbg linux-cachyos-kiln-headers linux-cachyos-kiln-nvidia-open; do
        touch "$T/last-good/$p-0-1-x86_64.pkg.tar.zst"
    done
}
run() { KILN_KERNEL_CACHE=$T kernel/rebuild.sh "$@" > "$T/out" 2>&1; echo "exit $?" >> "$T/out"; }

# Every call uses the test cache: never the real one, where a check could start a real rebuild.
echo "1. Last good is today's CachyOS commit"
setup 8c1b372
run; expect "nothing new" "Nothing new"

echo "2. Last good is 7.3.3 (6d02fae), its own profiles"
setup 6d02fae
run; expect "full rebuild" "Mode: full"; expect "review file" "Ready for review"
cat "$T"/rebuild/review-*.txt >> "$T/out"; expect "reason in the review: kernel version" "< kernel 7.3.3"
expect "stock version in the review" "released stock kernel, installed: linux-cachyos"
expect "full URLs in the review" "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/"
diff -q kernel/PKGBUILD "$T/rebuild/new/PKGBUILD" >/dev/null && { pass=$((pass + 1)); echo "  ok: new PKGBUILD = kernel/PKGBUILD"; } || { fail=$((fail + 1)); echo "  FAIL: PKGBUILD differs"; }
run; expect "waits for review" "Waiting for review"
run reviewed; expect "test cache refuses reviewed" "only check, status and cancel"
run cancel; expect "cancel at review" "Rebuild forgotten"

echo "3. Last good differs only in the NVIDIA version, profiles made with it"
setup 8c1b372 's/^_nv_ver=.*/_nv_ver=620.60.01/'
run; expect "quick rebuild" "Mode: quick"
run cancel

echo "4. Last good differs in one config line"
setup 8c1b372 "" '1i # kiln test line'
run; expect "full rebuild" "Mode: full"
run cancel

echo "5. Last good differs in a build line that is not about NVIDIA"
setup 8c1b372 's/^_tagrel=1/_tagrel=1 # x/'
run; expect "full rebuild" "Mode: full"
run cancel

echo "6. reviewed with nothing waiting"
run reviewed; expect "refused in a test cache" "only check, status and cancel"

# Not covered: the .. and unknown-address refusals need a fake CachyOS repository; and
# everything after review (build, install, restarts), which runs first for real.

rm -rf "$T"
echo "passed $pass, failed $fail"
