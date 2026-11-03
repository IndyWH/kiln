#!/bin/sh
# Kiln Linux: builds one extra kernel to choose from at boot, from mlrig's settings.
# Usage: sudo scripts/build-kernel.sh SOURCE COMPILER
# Example: sudo scripts/build-kernel.sh 7.3.1-gentoo gcc
# The name holds -kiln- and not -mlrig, so the boot menu's default never picks it.
set -eu
[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }
[ $# = 2 ] || { echo "Usage: build-kernel.sh SOURCE gcc|clang"; exit 1; }
SOURCE=$1
COMPILER=$2
case "$COMPILER" in
    gcc)   TOOLS="" ;;
    clang) TOOLS="LLVM=/usr/lib/llvm/22/bin/" ;;
    *)     echo "The compiler must be gcc or clang."; exit 1 ;;
esac

REPO=$(dirname "$(dirname "$(realpath "$0")")")
SRC=/usr/src/linux-$SOURCE
OUT=/usr/src/kiln-kernel/$SOURCE-$COMPILER
RESULTS=$REPO/results/kernels-$SOURCE-$(date +%Y-%m-%d)
SETTINGS=$REPO/config/kernel/kiln-$SOURCE-$COMPILER.config
LOG=$RESULTS/build-$COMPILER.log
[ -d "$SRC" ] || { echo "$SRC was not found."; exit 1; }

mkdir -p "$OUT" "$RESULTS"
cp "$REPO/config/kernel/mlrig-6.18.60.config" "$OUT/.config"
sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-kiln-$COMPILER\"/" "$OUT/.config"
make -s -C "$SRC" O="$OUT" $TOOLS olddefconfig >"$LOG" 2>&1

echo "Checking the settings survived the move to this version:"
for setting in X86_NATIVE_CPU PREEMPT HZ_1000 SCHED_MC INTEL_HFI_THERMAL BTRFS_FS DRM_AMDGPU; do
    if ! grep -Eq "^CONFIG_$setting=(y|m)" "$OUT/.config"; then
        echo "CONFIG_$setting is not on, so nothing was built."
        exit 1
    fi
done
grep -E '^CONFIG_(CC_IS_GCC|CC_IS_CLANG|LOCALVERSION)=' "$OUT/.config"

echo "Compiling. The full log is in $LOG"
nice -n 10 make -s -C "$SRC" O="$OUT" $TOOLS -j32 -l32 >>"$LOG" 2>&1
make -s -C "$SRC" O="$OUT" $TOOLS modules_install >>"$LOG" 2>&1
make -s -C "$SRC" O="$OUT" $TOOLS install >>"$LOG" 2>&1

cp "$OUT/.config" "$SETTINGS"
chown -R "${SUDO_USER:-root}:" "$RESULTS" "$SETTINGS"
echo "Built: $(make -s -C "$SRC" O="$OUT" kernelrelease)"
