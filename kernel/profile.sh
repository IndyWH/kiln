#!/usr/bin/env bash
# Records which kernel code this machine runs most, for AutoFDO and Propeller, while a
# workload runs: a full rebuild of the kernel in WORKLOAD_TREE (any configured kernel source
# tree; it is cleaned first), as CachyOS do. Then turns it into an AutoFDO profile for the
# running kernel, using its unstripped vmlinux from the -dbg package.
#
#   sudo kernel/profile.sh OUT_DIR WORKLOAD_TREE [PROPELLER_TOOL]
#
# Writes OUT_DIR/kernel.data (perf's record, large), OUT_DIR/kiln.afdo, and with the tool
# OUT_DIR/propeller_cc_profile.txt and propeller_ld_profile.txt.
# Event and settings from the kernel's Documentation/dev-tools/autofdo.rst; Intel LBR.
set -euo pipefail
out="${1:?output folder}"
tree="${2:?kernel tree to rebuild as the workload}"
owner=indy
release=$(uname -r)
vmlinux=/usr/src/debug/linux-cachyos-kiln/vmlinux
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
case $release in *-cachyos-kiln) ;; *) echo "not running Kiln's kernel: $release"; exit 1;; esac
[ -f "$vmlinux" ] || { echo "missing $vmlinux"; exit 1; }
mkdir -p "$out"
chown "$owner:" "$out"
runuser -u "$owner" -- make -C "$tree" LLVM=1 clean >/dev/null
# perf needs the kernel's addresses, which kptr_restrict=2 hides even from root. Shown only
# while recording, and put back whatever happens.
restrict=$(sysctl -n kernel.kptr_restrict)
trap 'sysctl -q kernel.kptr_restrict="$restrict"; echo "kptr_restrict back to $(sysctl -n kernel.kptr_restrict)"' EXIT
sysctl -q kernel.kptr_restrict=0
echo "Recording during a kernel build, $(date +%T)"
perf record -e BR_INST_RETIRED.NEAR_TAKEN:k -a -N -b -c 500009 -o "$out/kernel.data" -- \
    runuser -u "$owner" -- make -C "$tree" LLVM=1 -j"$(nproc)" -s vmlinux modules
sysctl -q kernel.kptr_restrict="$restrict"
echo "Converting, $(date +%T)"
chown "$owner:" "$out"/*
llvm-profgen --kernel --binary="$vmlinux" --perfdata="$out/kernel.data" -o "$out/kiln.afdo"
# Propeller, from the same recording, when the tool is given (built from google/llvm-propeller;
# see kernel/README.md). Run as the owner, never as root.
if [ -n "${3:-}" ]; then
    runuser -u "$owner" -- "$3" --binary="$vmlinux" --profile="$out/kernel.data" \
        --cc_profile="$out/propeller_cc_profile.txt" --ld_profile="$out/propeller_ld_profile.txt" \
        --propeller_options='output_module_name: true'
fi
chown "$owner:" "$out"/*
ls -la "$out"
