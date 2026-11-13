#!/usr/bin/env bash
# Builds Kiln's own kernel, linux-cachyos-kiln, from CachyOS's build script (PKGBUILD.cachyos,
# from github.com/CachyOS/linux-cachyos at commit 8c1b372, 13 Nov 2026) with Kiln's small
# changes (kiln.patch). Builds as the owner, never as root, in ~/.cache/kiln-kernel/stageN.
# Installing is a separate step.
#
#   kernel/build.sh 1                                 BORE, full LTO, ready to be profiled (AutoFDO)
#   kernel/build.sh 2 AUTOFDO_PROFILE                 plus the AutoFDO profile, ready to be profiled (Propeller)
#   kernel/build.sh 3 AUTOFDO_PROFILE PROPELLER_DIR   plus the Propeller profiles: the final kernel
set -euo pipefail
stage=${1:?stage 1, 2 or 3}
here=$(cd "$(dirname "$0")" && pwd)
dir="$HOME/.cache/kiln-kernel/stage$stage"
mkdir -p "$dir"
cp "$here/PKGBUILD" "$here/config" "$dir/"
cd "$dir"

# The strongest settings (Kiln's maximum-optimisation rule); CPU level x86-64-v3, never native.
export _cpusched=bore           # BORE scheduler, instead of CachyOS's default EEVDF
export _use_llvm_lto=full       # Clang full LTO, instead of CachyOS's thin
export _processor_opt=generic_v3
export _cc_harder=yes           # -O3
export _HZ_ticks=1000 _tickrate=full _preempt=full _hugepage=always   # as CachyOS's own; lazy tested, no gain
export _build_nvidia_open=yes   # NVIDIA module built with the kernel, no DKMS
export _build_debug=yes         # unstripped vmlinux, needed to turn a profile into something the compiler uses
export _autofdo=yes             # AUTOFDO_CLANG on in every stage, so each stage can be profiled
case $stage in
  1) ;;
  2) cp "${2:?AutoFDO profile}" kiln-autofdo.afdo
     export _autofdo_profile_name=kiln-autofdo.afdo _propeller=yes
     export _kiln_profile_b2sums="$(b2sum kiln-autofdo.afdo | cut -d' ' -f1)" ;;
  3) cp "${2:?AutoFDO profile}" kiln-autofdo.afdo
     cp "${3:?Propeller folder}"/propeller_{cc,ld}_profile.txt .
     export _autofdo_profile_name=kiln-autofdo.afdo _propeller=yes _propeller_profiles=yes
     export _kiln_profile_b2sums="$(b2sum kiln-autofdo.afdo propeller_cc_profile.txt propeller_ld_profile.txt | cut -d' ' -f1 | tr '\n' ' ')" ;;
  *) echo "stage 1, 2 or 3"; exit 64 ;;
esac
time makepkg --syncdeps --noconfirm --cleanbuild
ls -la "$dir"/*.pkg.tar.zst
