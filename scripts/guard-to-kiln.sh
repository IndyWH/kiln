#!/bin/bash
# Puts the disk guard on Kiln, before its first boot. The owner runs this by hand:
#   sudo scripts/guard-to-kiln.sh
# It writes only under /mnt/gentoo, after proving that is the Crucial, by serial.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
root=/mnt/gentoo
crucial=$(readlink -f /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC-part2)
source=$(findmnt -n -o SOURCE "$root" | sed 's/\[.*//')

[ "$(id -u)" = 0 ] || { echo "Run with sudo."; exit 1; }
[ -b "$crucial" ] || { echo "Crucial not found. Nothing changed."; exit 1; }
[ "$source" = "$crucial" ] || { echo "$root is not the Crucial. Nothing changed."; exit 1; }

install -D -o root -g root -m 0755 "$here/guard/kiln_guard.py" "$root/usr/local/lib/kiln-guard/kiln_guard.py"
install -D -o root -g root -m 0644 "$here/guard/99-kiln-guard.rules" "$root/etc/udev/rules.d/99-kiln-guard.rules"
install -D -o root -g root -m 0644 "$here/guard/managed-settings.json" "$root/etc/claude-code/managed-settings.json"
install -D -o root -g root -m 0644 "$here/config/etc/systemd/system/kiln-guard.service" "$root/etc/systemd/system/kiln-guard.service"
chroot "$root" systemctl enable kiln-guard.service

# The first-boot check, and the guard test it runs.
install -D -o root -g root -m 0755 "$here/scripts/first-boot-check.sh" "$root/usr/local/sbin/kiln-first-boot-check"
install -D -o root -g root -m 0755 "$here/tests/guard/fake_disks.sh" "$root/usr/local/share/kiln/tests/guard/fake_disks.sh"
install -D -o root -g root -m 0755 "$here/guard/kiln_guard.py" "$root/usr/local/share/kiln/guard/kiln_guard.py"
install -D -o root -g root -m 0644 "$here/guard/99-kiln-guard.rules" "$root/usr/local/share/kiln/guard/99-kiln-guard.rules"

echo
echo "Copied:"
cmp "$here/guard/kiln_guard.py" "$root/usr/local/lib/kiln-guard/kiln_guard.py" && echo "  guard program matches"
cmp "$here/guard/99-kiln-guard.rules" "$root/etc/udev/rules.d/99-kiln-guard.rules" && echo "  udev rule matches"
cmp "$here/guard/managed-settings.json" "$root/etc/claude-code/managed-settings.json" && echo "  hook settings match"
echo "  start-up service: $(chroot "$root" systemctl is-enabled kiln-guard.service)"
echo "Done."
