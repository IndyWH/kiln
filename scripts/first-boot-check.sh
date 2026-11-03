#!/bin/bash
# Kiln first-boot check. Run as root at the console, after each kernel's first boot:
#   kiln-first-boot-check
# Only reads the machine, apart from fake disks held in memory for the guard test.
# Results go to /var/log/kiln-first-boot/<kernel>/ on the Crucial.
set -u

kernel=$(uname -r)
out=/var/log/kiln-first-boot/$kernel
mkdir -p "$out"
fails=0

report() { # report PASS-or-FAIL words
  printf '%-5s %s\n' "$1" "$2" | tee -a "$out/result.txt"
  [ "$1" = FAIL ] && fails=$((fails + 1))
  return 0
}

check() { # check words -- command
  local words=$1
  shift
  if "$@" >/dev/null 2>&1; then report PASS "$words"; else report FAIL "$words"; fi
}

: >"$out/result.txt"
echo "Kernel: $kernel" | tee -a "$out/result.txt"

# Other disks: locked, and no writes since power on.
python3 -B /usr/local/lib/kiln-guard/kiln_guard.py status >"$out/guard-status.txt" 2>&1
check "Guard status is OK" grep -q '^Result: OK' "$out/guard-status.txt"
check "Guard start-up service ran" systemctl is-active kiln-guard.service
: >"$out/others.txt"
bad=0
for d in /sys/block/*; do
  name=${d##*/}
  case $name in loop* | ram* | zram* | sr*) continue ;; esac
  s=$(cat "$d/device/serial" 2>/dev/null | tr -d ' ')
  [ "$s" = 2128E5B7DBBC ] && continue
  read -r -a f <"$d/stat"
  ro=$(cat "$d/ro")
  echo "$name ro=$ro writes=${f[4]} sectors=${f[6]} discards=${f[11]} flushes=${f[15]}" >>"$out/others.txt"
  [ "$ro" = 1 ] && [ "${f[4]}" = 0 ] && [ "${f[6]}" = 0 ] && [ "${f[11]}" = 0 ] || bad=1
done
[ "$bad" = 0 ] && report PASS "Other disks locked, 0 writes" || report FAIL "Other disks locked, 0 writes"

# Boot order.
efibootmgr 2>/dev/null | grep '^BootOrder' >"$out/bootorder.txt"
first=$(sed 's/BootOrder: //; s/,.*//' "$out/bootorder.txt")
[ "$first" = 0000 ] && report PASS "Ubuntu is still first in the boot order" || report FAIL "Ubuntu is still first in the boot order"

# Microcode.
dmesg | grep -i microcode >"$out/microcode.txt"
grep -m1 '^microcode' /proc/cpuinfo >>"$out/microcode.txt"
check "Microcode revision is 0x137" grep -q '0x137' <(grep -m1 '^microcode' /proc/cpuinfo)
grep -qi 'old microcode' "$out/microcode.txt" && report FAIL "Old microcode warning has gone" || report PASS "Old microcode warning has gone"

# Screen, network, sound, serial adapter, Wi-Fi and Bluetooth.
driver_of() { basename "$(readlink "/sys/bus/pci/devices/$1/driver" 2>/dev/null)"; }
[ "$(driver_of 0000:02:00.0)" = amdgpu ] && report PASS "WX 3200 uses amdgpu" || report FAIL "WX 3200 uses amdgpu"
for m in igc snd_hda_intel snd_usb_audio cp210x iwlmvm btusb; do
  check "Driver $m is loaded" grep -q "^$m " /proc/modules
done
check "Serial adapter has a port" ls /dev/ttyUSB0
check "Wired network has a link" grep -qx up /sys/class/net/e*/operstate
check "Internet works" ping -c 1 -W 5 gentoo.org
lsmod | awk '{print $1}' | sort >"$out/modules.txt"

# NVIDIA, on the mlrig kernel only. The rescue kernel has no NVIDIA driver.
case $kernel in
  *-mlrig*)
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader >"$out/nvidia.txt" 2>&1
    check "nvidia-smi sees the RTX 4090" grep -q 'RTX 4090' "$out/nvidia.txt"
    ;;
esac
grep -q '^nouveau ' /proc/modules && report FAIL "nouveau is not loaded" || report PASS "nouveau is not loaded"

# Fast and efficient cores.
{ echo "threads $(nproc)"; echo "fast $(cat /sys/devices/cpu_core/cpus)"; echo "efficient $(cat /sys/devices/cpu_atom/cpus)"; dmesg | grep -i -E 'hfi|itmt'; } >"$out/cores.txt" 2>&1
[ "$(nproc)" = 32 ] && report PASS "All 32 threads are on" || report FAIL "All 32 threads are on"

# Start-up health. For reading, not pass or fail, apart from failed services.
systemd-analyze time >"$out/boot-time.txt" 2>&1
systemctl --failed --no-legend --plain >"$out/failed-services.txt" 2>&1
[ -s "$out/failed-services.txt" ] && report FAIL "No failed services" || report PASS "No failed services"
journalctl -b -p err --no-pager >"$out/errors.txt" 2>&1
dmesg >"$out/dmesg.txt" 2>&1

# The guard test, on fake disks in memory, with the rule as installed on Kiln.
/usr/local/share/kiln/tests/guard/fake_disks.sh --installed-rule >"$out/guard-test.log" 2>&1
rc=$?
[ "$rc" = 0 ] && report PASS "Guard test on fake disks" || report FAIL "Guard test on fake disks"

python3 -B /usr/local/lib/kiln-guard/kiln_guard.py status >"$out/guard-status-after.txt" 2>&1
echo
echo "Failed checks: $fails. Saved in $out"
