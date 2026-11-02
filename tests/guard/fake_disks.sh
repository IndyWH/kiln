#!/bin/bash
# Proves the kernel lock on fake disks that exist only in memory.
# Run as root. No real disk is written to, locked or changed.
#
# Every write goes through decoy_write, which first checks that the device is
# one of our fake disks. Real disks' write counts and lock flags are compared
# before and after, and any change fails the test.
#
# Usage: sudo tests/guard/fake_disks.sh [--installed-rule]
#   --installed-rule  also test the udev rule already installed on the system.
set -u

here=$(cd "$(dirname "$0")" && pwd)
guard="$here/../../guard/kiln_guard.py"
rules="$here/../../guard/99-kiln-guard.rules"
work=/run/kiln-guard-test
test_rule=/run/udev/rules.d/98-kiln-guard-test.rules
SD_MODEL=scsi_debug
passes=0
fails=0
loopdev=""

[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }

pass() { passes=$((passes + 1)); echo "PASS  $*"; }
fail() { fails=$((fails + 1)); echo "FAIL  $*"; }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got $2, wanted $3)"; fi; }

die() { echo "STOPPED: $*"; exit 3; }

# ---- which devices count as fake

is_fake_loop() {  # /dev/loopN or /dev/loopNpM, backed by our file on tmpfs
  local name=${1#/dev/} disk
  [[ $name =~ ^(loop[0-9]+)(p[0-9]+)?$ ]] || return 1
  disk=${BASH_REMATCH[1]}
  [ "$(cat "/sys/block/$disk/loop/backing_file" 2>/dev/null)" = "$work/disk.img" ] || return 1
  [ "$(findmnt -no FSTYPE -T "$work/disk.img")" = tmpfs ] || return 1
}

is_fake_scsi() {  # A disk made by the scsi_debug test module
  local name=${1#/dev/}
  [[ $name =~ ^sd[a-z]+$ ]] || return 1
  [ -e "/sys/block/$name/device/model" ] || return 1
  [[ $(cat "/sys/block/$name/device/model") == "$SD_MODEL"* ]] || return 1
  [[ $(cat "/sys/block/$name/device/vendor") == Linux* ]] || return 1
}

is_fake() { [ -b "$1" ] && { is_fake_loop "$1" || is_fake_scsi "$1"; }; }

decoy_write() {  # The only function that writes to a device. 0 means it worked.
  is_fake "$1" || die "$1 is not a fake disk. Nothing was written."
  # Written 4 MB in, clear of the partition table. nocreat: dd must never make a
  # plain file if the device node has gone.
  dd if=/dev/urandom of="$1" bs=4096 count=1 seek=1024 conv=fsync,notrunc,nocreat status=none 2>/dev/null
}

# ---- real disks: snapshot of write counts and lock flags

real_disks() {
  local d n
  for d in /sys/block/*; do
    n=${d##*/}
    case $n in loop*|ram*|zram*) continue ;; esac
    is_fake_scsi "$n" && continue
    echo "$n"
  done
}

snapshot() {  # Fields: writes, sectors written, discards, flushes
  local n
  for n in $(real_disks); do
    echo "$n ro=$(cat "/sys/block/$n/ro") $(awk '{print "writes="$5" sectors="$7" discards="$12" flushes="$16}' "/sys/block/$n/stat")"
  done
}

# ---- clean up, whatever happens

remove_scsi() {
  local i
  lsmod | grep -q '^scsi_debug' || return 0
  udevadm settle --timeout=20
  for i in 1 2 3 4 5 6 7 8 9 10; do
    modprobe -r scsi_debug 2>/dev/null && return 0
    sleep 1
    udevadm settle --timeout=5
  done
  echo "WARNING: scsi_debug could not be removed."
}

cleanup() {
  rm -f "$test_rule"
  udevadm control --reload 2>/dev/null
  remove_scsi
  if [ -n "$loopdev" ]; then
    # The flag outlives the fake disk and would carry over to the next user of
    # this loop device, so clear it. Only ever on our own checked fake disk.
    is_fake_loop "$loopdev" && blockdev --setrw "$loopdev" 2>/dev/null
    losetup -d "$loopdev" 2>/dev/null
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# ---- start

echo "=== Fake-disk proof"
echo "Kernel: $(uname -r)"
if lsmod | grep -q '^scsi_debug'; then die "scsi_debug is already loaded."; fi
mkdir -p "$work" || die "cannot make $work"
[ "$(findmnt -no FSTYPE -T "$work")" = tmpfs ] || die "$work is not in memory."

echo
echo "=== Real disks before (these must not change)"
before=$(snapshot)
echo "$before"

# ---- part 1: loop disk with a partition, backed by a file in memory

echo
echo "=== 1. Fake disk in memory: the write test can see a write"
truncate -s 32M "$work/disk.img"
printf 'label: gpt\n,,L\n' | sfdisk --quiet "$work/disk.img" || die "sfdisk on the image failed"
loopdev=$(losetup --find --show --partscan "$work/disk.img") || die "losetup failed"
udevadm settle --timeout=20
part=${loopdev}p1
is_fake_loop "$loopdev" || die "$loopdev is not our fake disk."
[ "$(cat "/sys/block/${loopdev#/dev/}/ro")" = 0 ] || die "$loopdev is still locked from an earlier run."
[ -b "$part" ] || die "$part did not appear."
echo "Fake disk: $loopdev, partition $part"

h0=$(sha256sum < "$work/disk.img")
if decoy_write "$loopdev"; then pass "Unlocked disk accepts a write"; else fail "Unlocked disk refused a write"; fi
blockdev --flushbufs "$loopdev"
h1=$(sha256sum < "$work/disk.img")
if [ "$h0" != "$h1" ]; then pass "That write changed the data, so the test can detect one"; else fail "The write did not change the data"; fi
h2=$h1
if decoy_write "$part"; then pass "Unlocked partition accepts a write"; else fail "Unlocked partition refused a write"; fi
blockdev --flushbufs "$loopdev"
h3=$(sha256sum < "$work/disk.img")
if [ "$h2" != "$h3" ]; then pass "That write changed the data too"; else fail "The partition write did not change the data"; fi

# A real filesystem, so that the mount test below is refused for the right reason.
is_fake "$part" || die "$part is not a fake disk."
mkfs.ext4 -q -F "$part" || die "mkfs on the unlocked fake partition failed"
udevadm settle --timeout=20
mkdir -p "$work/mnt"
is_fake "$part" || die "$part is not a fake disk."
if mount -w "$part" "$work/mnt"; then
  pass "Unlocked partition mounts read-write"
  umount "$work/mnt"
else
  fail "Unlocked partition would not mount read-write"
fi

echo
echo "=== 2. Locking sends no write: it opens the device read-only"
trace="$work/trace.txt"
strace -f -qq -e trace=openat,ioctl -o "$trace" /usr/bin/python3 -B "$guard" lock-one "${loopdev#/dev/}"
check "The guard locked the fake disk" "$?" 0
opens=$(grep -F "\"$loopdev\"" "$trace" | grep -c 'openat')
writes=$(grep -F "\"$loopdev\"" "$trace" | grep -cE 'O_WRONLY|O_RDWR')
if [ "$opens" -ge 1 ]; then pass "The lock step opened the device"; else fail "No open of the device was seen in the trace"; fi
check "Opens for writing during the lock" "$writes" 0
if grep -q 'BLKROSET' "$trace"; then pass "The lock is the kernel's read-only flag (BLKROSET)"; else fail "BLKROSET not seen in the trace"; fi

echo
echo "=== 3. Locked disk refuses every kind of write"
check "Kernel flag on the disk" "$(cat "/sys/block/${loopdev#/dev/}/ro")" 1
check "Kernel flag on the partition" "$(cat "/sys/block/${loopdev#/dev/}/${part#/dev/}/ro")" 1
hash_before=$(sha256sum < "$work/disk.img")

must_fail() {  # Name, then a command that only ever touches a checked fake disk
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then fail "$what was NOT refused"; else pass "$what refused"; fi
}
py_write() {
  is_fake "$1" || die "$1 is not a fake disk."
  /usr/bin/python3 -B -c 'import os,sys; f=os.open(sys.argv[1],os.O_WRONLY); os.write(f,b"x"*4096); os.fsync(f)' "$1"
}
tool() {  # Run a disk tool, after checking its last argument is a fake disk
  local dev=${!#}
  is_fake "$dev" || die "$dev is not a fake disk."
  "$@"
}

must_fail "dd to the disk" decoy_write "$loopdev"
must_fail "dd to the partition" decoy_write "$part"
must_fail "Direct write from a program, disk" py_write "$loopdev"
must_fail "Direct write from a program, partition" py_write "$part"
must_fail "blkdiscard on the disk" tool blkdiscard -f "$loopdev"
must_fail "blkdiscard on the partition" tool blkdiscard -f "$part"
must_fail "mkfs on the partition" tool mkfs.ext4 -q -F "$part"
must_fail "mkfs on the disk" tool mkfs.ext4 -q -F "$loopdev"
must_fail "Partition wipe" tool wipefs -a -f "$loopdev"
# sgdisk exits 0 and prints "destroyed" even when every write was refused, so its
# exit code proves nothing. Judge it by what the kernel answered, and by the data.
is_fake "$loopdev" || die "$loopdev is not a fake disk."
sg_trace="$work/sgdisk.txt"
strace -f -qq -e trace=write,pwrite64,pwritev -o "$sg_trace" sgdisk --zap-all "$loopdev" >/dev/null 2>&1
refused=$(grep -vE 'write\((1|2),' "$sg_trace" | grep -c '= -1 EPERM')
landed=$(grep -vE 'write\((1|2),' "$sg_trace" | grep -E 'write|pwrite' | grep -vc '= -1 ')
if [ "$refused" -ge 1 ]; then pass "Partition table change: kernel refused $refused writes"; else fail "Partition table change: no refused write seen"; fi
check "Partition table change: writes that landed" "$landed" 0
mount_rw() {
  is_fake "$1" || die "$1 is not a fake disk."
  if mount -w "$1" "$work/mnt"; then umount "$work/mnt"; return 0; fi
  return 1
}
must_fail "Read-write mount" mount_rw "$part"

blockdev --flushbufs "$loopdev" 2>/dev/null
check "Data on the fake disk is unchanged" "$(sha256sum < "$work/disk.img")" "$hash_before"

echo
echo "=== 4. Guard refuses to lock or change what it should not"
/usr/bin/python3 -B "$guard" lock-one 'bad name; rm -rf x' >/dev/null 2>&1
if [ "$?" != 0 ]; then pass "Bad device name refused"; else fail "Bad device name accepted"; fi

# ---- part 2: a new disk appears while running

load_scsi() {
  modprobe scsi_debug dev_size_mb=16 num_tgts=1 max_luns=1 || die "modprobe scsi_debug failed"
  udevadm settle --timeout=20
  sd=""
  local p
  for p in /sys/bus/pseudo/drivers/scsi_debug/adapter*/host*/target*/*/block/*; do
    [ -e "$p" ] && sd=${p##*/}
  done
  [ -n "$sd" ] || die "The fake disk did not appear."
  is_fake_scsi "$sd" || die "$sd is not a scsi_debug disk."
  sleep_settle
}
sleep_settle() { udevadm settle --timeout=20; sleep 1; udevadm settle --timeout=20; }

echo
echo "=== 5. New fake disk with no rule in place: the test can see a write"
load_scsi
echo "Fake disk: $sd (model $(cat "/sys/block/$sd/device/model"))"
check "Without the rule, it starts unlocked" "$(cat "/sys/block/$sd/ro")" 0
h0=$(sha256sum < "/dev/$sd")
if decoy_write "/dev/$sd"; then pass "It accepts a write"; else fail "It refused a write"; fi
blockdev --flushbufs "/dev/$sd"
h1=$(sha256sum < "/dev/$sd")
if [ "$h0" != "$h1" ]; then pass "That write changed the data"; else fail "The write did not change the data"; fi
remove_scsi

echo
echo "=== 6. New fake disk with the real rule: it locks itself"
# The real rule, with one extra line so that it can only act on scsi_debug disks.
# Until the owner approves the install, no real disk may be locked.
{
  echo "ATTRS{model}!=\"$SD_MODEL*\", GOTO=\"kiln_guard_end\""
  sed "s#/usr/local/lib/kiln-guard/kiln_guard.py#$guard#" "$rules"
} > "$test_rule"
udevadm control --reload
load_scsi
echo "Fake disk: $sd"
check "It was locked when it appeared" "$(cat "/sys/block/$sd/ro")" 1
hash_before=$(sha256sum < "/dev/$sd")
must_fail "dd to the new disk" decoy_write "/dev/$sd"
must_fail "Direct write from a program" py_write "/dev/$sd"
must_fail "mkfs on the new disk" tool mkfs.ext4 -q -F "/dev/$sd"
blockdev --flushbufs "/dev/$sd" 2>/dev/null
check "Its data is unchanged" "$(sha256sum < "/dev/$sd")" "$hash_before"
remove_scsi
rm -f "$test_rule"
udevadm control --reload

if [ "${1:-}" = --installed-rule ]; then
  echo
  echo "=== 7. New fake disk with the rule installed on the system"
  [ -e /etc/udev/rules.d/99-kiln-guard.rules ] || die "The rule is not installed."
  load_scsi
  echo "Fake disk: $sd"
  check "It was locked when it appeared" "$(cat "/sys/block/$sd/ro")" 1
  must_fail "dd to the new disk" decoy_write "/dev/$sd"
  remove_scsi
fi

# ---- real disks: nothing changed

echo
echo "=== Real disks after"
after=$(snapshot)
echo "$after"
crucial=$(/usr/bin/python3 -B -c '
import sys; sys.dont_write_bytecode=True; sys.path.insert(0, sys.argv[1])
import kiln_guard as g; print(g.Disks().target() or "")' "$here/../../guard")
[ -n "$crucial" ] || fail "The Crucial was not found by serial"
others_before=$(echo "$before" | grep -v "^$crucial ")
others_after=$(echo "$after" | grep -v "^$crucial ")
check "Other real disks: write counts and lock flags unchanged" \
  "$(echo "$others_after" | sha256sum)" "$(echo "$others_before" | sha256sum)"
check "The Crucial: write count and lock flag unchanged" \
  "$(echo "$after" | grep "^$crucial ")" "$(echo "$before" | grep "^$crucial ")"

echo
echo "=== Result: $passes passed, $fails failed"
[ "$fails" = 0 ]
