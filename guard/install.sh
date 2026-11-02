#!/bin/bash
# Install the Kiln disk guard. Run as root. Safe to run again.
# On the live system nothing survives a restart: run this again after each boot.
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)

# Do not overwrite a settings file this script did not write.
settings=/etc/claude-code/managed-settings.json
if [ -e "$settings" ] && ! cmp -s "$here/managed-settings.json" "$settings"; then
  echo "$settings already exists and is different. Stopping."
  exit 1
fi

install -d -m 755 -o root -g root /usr/local/lib/kiln-guard /etc/udev/rules.d /etc/claude-code
install -m 755 -o root -g root "$here/kiln_guard.py" /usr/local/lib/kiln-guard/kiln_guard.py
install -m 644 -o root -g root "$here/99-kiln-guard.rules" /etc/udev/rules.d/99-kiln-guard.rules

# The kernel lock goes on before the hook, so there is no unlocked gap once
# Claude Code starts using the hook.
udevadm control --reload
rc=0
/usr/bin/python3 /usr/local/lib/kiln-guard/kiln_guard.py lock || rc=$?
install -m 644 -o root -g root "$here/managed-settings.json" "$settings"

/usr/bin/python3 /usr/local/lib/kiln-guard/kiln_guard.py status || rc=$?
if [ "$rc" != 0 ]; then
  echo "THE GUARD IS NOT SAFE. Do no disk work."
  exit 1
fi
echo "Guard installed. Restart Claude Code so it loads the hook."
