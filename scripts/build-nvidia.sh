#!/bin/sh
# Kiln Linux: builds NVIDIA's open kernel modules for one extra Clang kernel.
# Usage: sudo scripts/build-nvidia.sh SOURCE VARIANT
# Example: sudo scripts/build-nvidia.sh 7.3.1-gentoo clang-fulllto
#
# Gentoo's nvidia-drivers package builds modules for /usr/src/linux only, which stays
# on 6.18. These go beside the extra kernel, unknown to Portage, so 6.18 is not touched.
# Run this again after nvidia-drivers updates, because the versions must match.
set -eu
[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }
[ $# = 2 ] || { echo "Usage: build-nvidia.sh SOURCE VARIANT"; exit 1; }
SOURCE=$1
VARIANT=$2

VERSION=595.104.02
[ -d "/var/db/pkg/x11-drivers/nvidia-drivers-$VERSION" ] || {
    echo "nvidia-drivers $VERSION is not the installed version. Update this script."; exit 1; }

REPO=$(dirname "$(dirname "$(realpath "$0")")")
TARBALL=/var/cache/distfiles/NVIDIA-kernel-module-source-$VERSION.tar.xz
SRC=/usr/src/linux-$SOURCE
OUT=/usr/src/kiln-kernel/$SOURCE-$VARIANT
WORK=/usr/src/kiln-kernel/nvidia-$VERSION-$SOURCE-$VARIANT
RELEASE=$(make -s -C "$SRC" O="$OUT" kernelrelease)
TARGET=/lib/modules/$RELEASE/video
RESULTS=$REPO/results/kernels-$SOURCE-$(date +%Y-%m-%d)
LOG=$RESULTS/build-nvidia-$VARIANT.log
BIN=/usr/lib/llvm/22/bin
[ -f "$OUT/vmlinux" ] || { echo "$OUT has no built kernel."; exit 1; }

mkdir -p "$RESULTS"
rm -rf "$WORK"
mkdir -p "$WORK"
tar -xf "$TARBALL" -C "$WORK" --strip-components=1

echo "Compiling NVIDIA $VERSION for $RELEASE. The full log is in $LOG"
nice -n 10 make -C "$WORK" modules -j32 \
    SYSSRC="$SRC" SYSOUT="$OUT" LLVM="$BIN/" \
    CC="$BIN/clang" CXX="$BIN/clang++" LD="$BIN/ld.lld" AR="$BIN/llvm-ar" \
    OBJCOPY="$BIN/llvm-objcopy" NM="$BIN/llvm-nm" STRIP="$BIN/llvm-strip" \
    OBJDUMP="$BIN/llvm-objdump" HOSTCC="$BIN/clang" HOSTCXX="$BIN/clang++" \
    IGNORE_CC_MISMATCH=yes ARCH=x86_64 TARGET_ARCH=x86_64 NV_VERBOSE=1 >"$LOG" 2>&1

mkdir -p "$TARGET"
for module in nvidia nvidia-drm nvidia-modeset nvidia-peermem nvidia-uvm; do
    install -m 644 "$WORK/kernel-open/$module.ko" "$TARGET/$module.ko"
done
depmod -a "$RELEASE"
chown -R "${SUDO_USER:-root}:" "$RESULTS"
ls "$TARGET"
echo "Built NVIDIA $VERSION for $RELEASE. Nothing is loaded yet."
