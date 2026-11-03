#!/usr/bin/python3
"""Tests for the rules hook. No snapshots are taken and no real log is touched."""
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
sys.path[:0] = [os.path.join(ROOT, "guard"), os.path.join(ROOT, "sidekick")]
import kiln_rules as r

REPO = os.path.expanduser("~/Projects/kiln")


def kind(command, cwd=REPO):
    return r.text_kind(command, cwd)


class Commands(unittest.TestCase):
    def test_reads(self):
        for c in ("ls -l /etc", "cat /etc/fstab | grep root", "git status -sb",
                  "git log --oneline -3", "git add . && git commit -m x",
                  "systemctl is-active sshd", "systemctl --failed",
                  "hyprctl -j monitors", "hyprctl clients", "wpctl status",
                  "pactl list short sinks", "sudo snapper -c root list",
                  "sudo bootctl list --no-pager", "emerge --pretend vim", "emerge -pv vim",
                  "ip -br addr", "journalctl -b -p err", "find /etc -name x",
                  "sed -n 1,5p f", "echo hi > /dev/null", "ls 2>/dev/null",
                  "for f in a b; do cat $f; done", "echo hi > notes.txt", "/usr/bin/ls",
                  "date +%s", "hostname", "ss -tln", "set -e",
                  "sudo python3 /usr/local/lib/kiln-guard/kiln_guard.py status",
                  'X="$(cat /etc/fstab)"; echo "$X"'):
            self.assertEqual(kind(c), r.READ, c)

    def test_changes(self):
        for c in ("sudo emerge vim", "emerge --depclean", "rm -rf /etc/foo", "touch x",
                  "echo hi > /etc/motd", "echo hi >> ~/.bashrc", "sed -i s/a/b/ f",
                  "systemctl restart sshd", "hyprctl dispatch exit", "hyprctl reload",
                  "wpctl set-volume 60 0.5", "git reset --hard", "git checkout main",
                  "git -c core.pager=x log", "git log --output=/etc/x",
                  "git config user.name x", "find . -delete", "find . -exec rm {} ;",
                  "ip link set eno2 down", "efibootmgr -o 0000", "sudo snapper -c root delete 3",
                  "sudo btrfs subvolume delete /x", "sort -o /etc/x y",
                  "awk 'BEGIN{system(\"reboot\")}'", "python3 x.py", "unknownprogram",
                  'X="$(rm -rf /etc/foo)"', "cd /etc; echo hi > motd", "curl -o x y",
                  "sudo tee /etc/motd", "sed 's/a/b/w /etc/x' f", "echo hi > $HOME/x",
                  "echo hi > ../outside", "./ls", "/tmp/x/cat f", "journalctl --vacuum-size=1M",
                  "date -s 2020-01-01", "hostname other", "ss -K",
                  "sudo python3 /usr/local/lib/kiln-guard/kiln_guard.py lock"):
            self.assertEqual(kind(c), r.CHANGE, c)

    def test_push_is_outward(self):
        self.assertEqual(kind("git push origin main"), r.OUTWARD)
        self.assertEqual(kind("git status; git push"), r.OUTWARD)
        self.assertEqual(kind("git push; rm x"), r.CHANGE)

    def test_rescue_kernel(self):
        for c in ("sudo emerge -C gentoo-kernel-bin",
                  "sudo emerge --unmerge sys-kernel/gentoo-kernel-bin",
                  "sudo rm -rf /lib/modules/6.18.60-gentoo-dist-bin",
                  "sudo rm -rf /boot/somewhere", "rm /boot/x", "sudo rm -rf /boot",
                  "sudo bootctl remove", "sudo kernel-install remove 6.18.60-gentoo-dist-bin"):
            with self.assertRaises(r.Refused, msg=c):
                r.check_rescue_command(c)
        for c in ("ls /boot", "sudo bootctl list", "emerge -pv gentoo-kernel-bin",
                  "sudo emerge gentoo-kernel-bin", "rm /tmp/boot"):
            r.check_rescue_command(c)


class Judge(unittest.TestCase):
    def test_description_needed(self):
        with self.assertRaises(r.Refused):
            r.judge({"tool_input": {"command": "sudo emerge vim"}, "cwd": REPO})
        with self.assertRaises(r.Refused):
            r.judge({"tool_input": {"command": "sudo emerge vim", "description": "emerge"},
                     "cwd": REPO})
        got = r.judge({"tool_input": {"command": "sudo emerge vim",
                                      "description": "Install the vim editor"}, "cwd": REPO})
        self.assertEqual(got[:2], (r.CHANGE, "Install the vim editor"))

    def test_read_needs_no_description(self):
        self.assertEqual(r.judge({"tool_input": {"command": "ls"}, "cwd": REPO})[0], r.READ)

    def test_files(self):
        def file_kind(path):
            return r.judge({"tool_input": {"file_path": path}, "cwd": REPO})[0]
        self.assertEqual(file_kind(REPO + "/HANDOVER.md"), r.READ)
        self.assertEqual(file_kind("/tmp/claude-%d/x" % os.getuid()), r.READ)
        self.assertEqual(file_kind("/etc/motd"), r.CHANGE)
        self.assertEqual(file_kind(os.path.expanduser("~/.config/hypr/hyprland.lua")), r.CHANGE)
        self.assertEqual(file_kind(os.path.expanduser("~/.claude/settings.json")), r.CHANGE)
        self.assertEqual(file_kind(REPO + "/.git/hooks/pre-commit"), r.CHANGE)
        self.assertEqual(file_kind(REPO + "/../outside"), r.CHANGE)
        with self.assertRaises(r.Refused):
            file_kind("/boot/loader/entries/x-6.18.60-gentoo-dist-bin.conf")

    def test_last_words(self):
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
            f.write(json.dumps({"type": "assistant", "message": {"content": [
                {"type": "text", "text": "This  sets the\nvolume."},
                {"type": "tool_use", "name": "Edit"}]}}) + "\n")
            f.write(json.dumps({"type": "user", "message": {"content": "ok"}}) + "\n")
            f.write("not json\n")
        self.assertEqual(r.last_words(f.name), "This sets the volume.")
        os.unlink(f.name)
        self.assertEqual(r.last_words("/nonexistent"), "")
        self.assertEqual(r.last_words(None), "")


class Flow(unittest.TestCase):
    """The hooks and the log, with snapper replaced."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        r.LOG = self.dir + "/changes.log"
        r.PENDING = self.dir
        self.count = {"root": 10, "home": 20}
        self.real_snapper, self.real_rescue = r.snapper, r.rescue_entry_present

        def fake(config, *args):
            self.count[config] += 1
            return str(self.count[config])
        r.snapper = fake
        r.rescue_entry_present = lambda: True

    def tearDown(self):
        r.snapper, r.rescue_entry_present = self.real_snapper, self.real_rescue

    def run_change(self, tool_id, event="PostToolUse", **extra):
        payload = {"tool_use_id": tool_id, "cwd": REPO, "hook_event_name": event,
                   "tool_input": {"command": "sudo emerge vim",
                                  "description": "Install the vim editor", **extra}}
        self.assertEqual(r.hook_pre(payload), 0)
        return payload

    def test_done_then_undoable(self):
        r.hook_post(self.run_change("a"))
        got = r.read_changes(r.LOG)
        self.assertEqual(len(got), 1)
        self.assertEqual((got[0]["root"], got[0]["root2"]), ("11", "12"))
        self.assertEqual((got[0]["home"], got[0]["home2"]), ("21", "22"))
        self.assertEqual(got[0]["said"], "Install the vim editor")

    def test_refused_by_owner_is_not_undoable(self):
        self.run_change("a")  # Asked, but the post hook never came.
        self.assertEqual(r.read_changes(r.LOG), [])

    def test_failed_can_be_undone(self):
        r.hook_post(self.run_change("a", event="PostToolUseFailure"))
        self.assertEqual(len(r.read_changes(r.LOG)), 1)

    def test_background_goes_back_to_now(self):
        r.hook_post(self.run_change("a", run_in_background=True))
        got = r.read_changes(r.LOG)
        self.assertEqual((got[0]["root2"], got[0]["home2"]), ("0", "0"))

    def test_undone_is_skipped(self):
        r.hook_post(self.run_change("a"))
        r.hook_post(self.run_change("b"))
        self.assertEqual(r.read_changes(r.LOG)[-1]["number"], 2)
        r.add_line(2, "UNDONE")
        self.assertEqual(r.read_changes(r.LOG)[-1]["number"], 1)

    def test_push_has_no_snapshot(self):
        payload = {"tool_use_id": "p", "cwd": REPO, "hook_event_name": "PostToolUse",
                   "tool_input": {"command": "git push", "description": "Send to GitHub"}}
        r.hook_pre(payload)
        r.hook_post(payload)
        self.assertEqual(self.count, {"root": 10, "home": 20})
        self.assertEqual(r.read_changes(r.LOG), [])

    def test_post_of_a_read_does_nothing(self):
        self.assertEqual(r.hook_post({"tool_use_id": "none"}), 0)

    def test_missing_rescue_kernel_is_reported(self):
        r.rescue_entry_present = lambda: False
        self.assertEqual(r.hook_post(self.run_change("a")), 2)


class Undo(unittest.TestCase):
    def test_changes_before_a_restore_cannot_be_undone(self):
        folder = tempfile.mkdtemp()
        r.LOG = folder + "/changes.log"
        with open(r.LOG, "w") as f:
            f.write("2026-11-03 10:00  #1 ASKED [root 11 home 11] Before\n")
            f.write("2026-11-03 10:00  #1 DONE [root 12 home 12]\n")
            f.write("2026-11-03 10:01  #0 RESTORED to snapshot 6, kept as @.old-1\n")
            f.write("2026-11-03 10:02  #2 ASKED [root 13 home 13] After\n")
            f.write("2026-11-03 10:02  #2 DONE [root 14 home 14]\n")
        self.assertEqual([e["number"] for e in r.read_changes(r.LOG)], [2])

    def test_a_change_that_changed_nothing_is_skipped(self):
        folder = tempfile.mkdtemp()
        r.LOG = folder + "/changes.log"
        for number, root in ((1, 11), (2, 13)):
            with open(r.LOG, "a") as f:
                f.write("2026-11-03 10:00  #%d ASKED [root %d home %d] Change %d\n"
                        % (number, root, root, number))
            r.add_line(number, "DONE", {"root": root + 1, "home": root + 1})

        real = r.root_snapper
        r.root_snapper = lambda config, command, span: (
            "c..... /etc/motd\n" if config == "root" and span == "11..12" else "")
        try:
            last, system, settings = r.find_last(r.read_changes(r.LOG))
            self.assertEqual(last["number"], 1)
            self.assertEqual((system, settings), (["c..... /etc/motd"], []))
            self.assertEqual([e["number"] for e in r.read_changes(r.LOG)], [1])
            r.add_line(1, "UNDONE")
            self.assertIsNone(r.find_last(r.read_changes(r.LOG))[0])
        finally:
            r.root_snapper = real

    def test_only_settings_are_restored(self):
        listing = "\n".join((
            "c..... /home/indy/.config/hypr/hyprland.lua",
            "+..... /home/indy/.config/my app/new file",
            "c..... /home/indy/.config/mozilla/firefox/prefs.js",
            "c..... /home/indy/.configx/other",
            "c..... /home/indy/Projects/kiln/HANDOVER.md",
            "c..... /home/indy/.git-credentials"))
        self.assertEqual(r.changed_settings(listing), [
            "/home/indy/.config/hypr/hyprland.lua", "/home/indy/.config/my app/new file"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
