#!/usr/bin/env bash
# Kiln Linux: the overnight run of 4 Nov 2026. Each block stands alone, so one failure does not
# stop the others. Everything stays in the lab, in memory. Nothing is installed.
# Usage: KILN_LAB=/path scripts/rust-llvm-overfire.sh

export KILN_LAB=${KILN_LAB:?set KILN_LAB}
LAB=$KILN_LAB
SELF=$(readlink -f "$0")
REPO=$(dirname "$SELF")/..
cd "$REPO" || exit 1

said() { echo "=== $(date '+%H:%M') $*"; }
ok() { said "done: $1"; }
failed() { said "FAILED: $1"; }
clean() { rm -rf "$LAB/raw" "$LAB/train"; }

# Linked ready for BOLT, as scripts/rust-llvm-lab.sh explains.
BOLTABLE="relocs=1 static=symbolic"
SAFETY_OFF="-fno-stack-protector -fno-stack-clash-protection -fcf-protection=none -D_FORTIFY_SOURCE=0"
export TRAIN_SET=rich

said "1. the real program: installed, and the best so far"
{ scripts/rust-llvm-lab.sh real ours "installed" &&
  scripts/rust-llvm-lab.sh real thin-bolt "ThinLTO PGO BOLT, plain training"; } && ok 1 || failed 1

said "2. richer training: ThinLTO, then BOLT"
{ scripts/rust-llvm-lab.sh train instr "$LAB/rich.profdata" &&
  scripts/rust-llvm-lab.sh build rich-thin profile="$LAB/rich.profdata" lto=thin $BOLTABLE &&
  scripts/rust-llvm-lab.sh bench rich-thin "ThinLTO PGO, richer training" &&
  scripts/rust-llvm-lab.sh bolt rich-thin-bolt rich-thin &&
  scripts/rust-llvm-lab.sh bench rich-thin-bolt "ThinLTO PGO BOLT, richer training" &&
  scripts/rust-llvm-lab.sh real rich-thin-bolt "ThinLTO PGO BOLT, richer training"; } && ok 2 || failed 2
clean

said "3. a second profile, CSIR-PGO, on ThinLTO"
{ scripts/rust-llvm-lab.sh build cs-instr instr=cs profile="$LAB/rich.profdata" lto=thin &&
  scripts/rust-llvm-lab.sh train cs-instr "$LAB/cs.profdata" "$LAB/rich.profdata" &&
  rm -rf "$LAB/builds/cs-instr" "$LAB/mix/cs-instr" &&
  scripts/rust-llvm-lab.sh build cs-thin profile="$LAB/cs.profdata" lto=thin $BOLTABLE &&
  scripts/rust-llvm-lab.sh bench cs-thin "ThinLTO, both profiles, richer training" &&
  scripts/rust-llvm-lab.sh bolt cs-thin-bolt cs-thin &&
  scripts/rust-llvm-lab.sh bench cs-thin-bolt "ThinLTO, both profiles, BOLT" &&
  scripts/rust-llvm-lab.sh real cs-thin-bolt "ThinLTO, both profiles, BOLT"; } && ok 3 || failed 3
clean

said "4. splitting cold code at compile time"
{ scripts/rust-llvm-lab.sh build split-thin profile="$LAB/rich.profdata" lto=thin $BOLTABLE flags="-fsplit-machine-functions" &&
  scripts/rust-llvm-lab.sh bench split-thin "ThinLTO PGO, split at compile time" &&
  scripts/rust-llvm-lab.sh bolt split-thin-bolt split-thin &&
  scripts/rust-llvm-lab.sh bench split-thin-bolt "ThinLTO PGO, split at compile time, BOLT"; } && ok 4 || failed 4
rm -rf "$LAB/builds/split-thin"
clean

said "5. Gentoo's safety settings off, with their own profile, on top of BOLT"
{ scripts/rust-llvm-lab.sh train instr-nohard "$LAB/nohard-rich.profdata" &&
  scripts/rust-llvm-lab.sh build nohard-thin profile="$LAB/nohard-rich.profdata" lto=thin $BOLTABLE flags="$SAFETY_OFF" &&
  scripts/rust-llvm-lab.sh bench nohard-thin "ThinLTO PGO, safety settings off" &&
  scripts/rust-llvm-lab.sh bolt nohard-thin-bolt nohard-thin &&
  scripts/rust-llvm-lab.sh bench nohard-thin-bolt "ThinLTO PGO BOLT, safety settings off" &&
  scripts/rust-llvm-lab.sh real nohard-thin-bolt "ThinLTO PGO BOLT, safety settings off"; } && ok 5 || failed 5
rm -rf "$LAB/builds/nohard-thin"
clean

said "6. Full LTO with richer training, then BOLT. About 2 hours for the link"
{ scripts/rust-llvm-lab.sh build rich-full profile="$LAB/rich.profdata" lto=full $BOLTABLE &&
  scripts/rust-llvm-lab.sh bench rich-full "Full LTO PGO, richer training" &&
  scripts/rust-llvm-lab.sh bolt rich-full-bolt rich-full &&
  scripts/rust-llvm-lab.sh bench rich-full-bolt "Full LTO PGO BOLT, richer training" &&
  scripts/rust-llvm-lab.sh real rich-full-bolt "Full LTO PGO BOLT, richer training"; } && ok 6 || failed 6
clean

said "7. Full LTO with both profiles, then BOLT. Two long links"
{ scripts/rust-llvm-lab.sh build cs-full-instr instr=cs profile="$LAB/rich.profdata" lto=full &&
  TRAIN_POOL=1 scripts/rust-llvm-lab.sh train cs-full-instr "$LAB/cs-full.profdata" "$LAB/rich.profdata" &&
  rm -rf "$LAB/builds/cs-full-instr" "$LAB/mix/cs-full-instr" &&
  scripts/rust-llvm-lab.sh build cs-full profile="$LAB/cs-full.profdata" lto=full $BOLTABLE &&
  scripts/rust-llvm-lab.sh bench cs-full "Full LTO, both profiles" &&
  scripts/rust-llvm-lab.sh bolt cs-full-bolt cs-full &&
  scripts/rust-llvm-lab.sh bench cs-full-bolt "Full LTO, both profiles, BOLT" &&
  scripts/rust-llvm-lab.sh real cs-full-bolt "Full LTO, both profiles, BOLT"; } && ok 7 || failed 7
clean
said "all finished"
