#!/bin/sh
# Kiln Linux: installs the hooks for rules 1 and 2, the change log and undo.
# The owner runs this by hand, because the guard stops Claude changing these places.
# Run after guard/install.sh, with: sudo sidekick/install.sh
set -eu
[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }
HERE=$(dirname "$(realpath "$0")")
REPO=$(dirname "$HERE")
OWNER=${SUDO_USER:-indy}
GUARD=/usr/local/lib/kiln-guard
[ -e "$GUARD/kiln_guard.py" ] || { echo "Install the disk guard first."; exit 1; }

echo "1. Tests"
for t in test_rules.py test_snapshot_menu.py; do
    python3 -B "$REPO/tests/sidekick/$t" >/dev/null 2>&1 || {
        echo "The tests failed, so nothing was installed."; exit 1; }
done

echo "2. Hook, undo and restore commands, boot menu program"
install -m 755 "$HERE/kiln_rules.py" "$GUARD/kiln_rules.py"
install -m 755 "$HERE/kiln_snapshots.py" "$GUARD/kiln_snapshots.py"
install -m 755 "$HERE/undo" /usr/local/bin/undo
install -m 755 "$HERE/restore" /usr/local/bin/restore
rm -f /usr/local/bin/kiln-snapshot-menu

echo "3. Change log, in /var/log/kiln/changes.log"
install -d -m 2775 -g "$OWNER" /var/log/kiln /var/log/kiln/pending
touch /var/log/kiln/changes.log
chgrp "$OWNER" /var/log/kiln/changes.log
chmod 664 /var/log/kiln/changes.log

echo "4. Snapshots of the home folder"
if ! snapper list-configs | grep -q '^home '; then
    snapper -c home create-config /home
fi
install -m 640 "$REPO/config/snapper/home" /etc/snapper/configs/home
systemctl enable --now snapper-cleanup.timer

echo "5. Boot menu service"
install -m 644 "$REPO/config/etc/systemd/system/kiln-snapshot-menu.service" \
    "$REPO/config/etc/systemd/system/kiln-snapshot-menu.path" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now kiln-snapshot-menu.path
systemctl enable kiln-snapshot-menu.service
systemctl restart kiln-snapshot-menu.service

echo "6. Rules file and hook settings"
install -m 644 "$REPO/config/claude/CLAUDE.md" /etc/claude-code/CLAUDE.md
install -d -m 755 /etc/claude-code/managed-settings.d
install -m 644 "$HERE/rules-settings.json" /etc/claude-code/managed-settings.d/50-kiln-rules.json
rm -f "/home/$OWNER/.claude/CLAUDE.md"

echo "7. Reading it back"
python3 -m json.tool /etc/claude-code/managed-settings.d/50-kiln-rules.json >/dev/null
cmp "$HERE/kiln_rules.py" "$GUARD/kiln_rules.py"
cmp "$HERE/kiln_snapshots.py" "$GUARD/kiln_snapshots.py"
snapper -c home list >/dev/null
sudo -u "$OWNER" sudo -n snapper -c home list >/dev/null
sudo -u "$OWNER" test -w /var/log/kiln/changes.log
python3 "$GUARD/kiln_guard.py" status | tail -1

echo
echo "Installed. Now type /exit in Claude Code, and start it again with: claude --continue"
