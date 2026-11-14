#!/usr/bin/python3
"""Tests for the rules hook. No snapshots are taken and no real log is touched."""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
sys.path[:0] = [os.path.join(ROOT, "guard"), os.path.join(ROOT, "sidekick")]
import kiln_rules as r

REPO = os.path.expanduser("~/Projects/kiln")
HOME = r.OWNER_HOME


def kind(command, cwd=REPO):
    return r.text_kind(command, cwd)


class Commands(unittest.TestCase):
    def test_reads(self):
        for c in ("ls -l /etc", "cat /etc/fstab | grep root", "git status -sb",
                  "git log --oneline -3", "git add . && git commit -m x",
                  "systemctl is-active sshd", "systemctl --failed",
                  "hyprctl -j monitors", "hyprctl clients", "wpctl status",
                  "pactl list short sinks", "sudo snapper -c root list",
                  "pacman -Q linux-cachyos", "pacman -Qi vim", "pacman -Ss vim",
                  "pacman -Si vim", "paru -Ss foo", "pacman -F libfoo.so", "checkupdates",
                  "nvidia-smi", "ip -br addr", "journalctl -b -p err", "find /etc -name x",
                  "sed -n 1,5p f", "echo hi > /dev/null", "ls 2>/dev/null",
                  "for f in a b; do cat $f; done", "echo hi > notes.txt", "/usr/bin/ls",
                  "date +%s", "hostname", "ss -tln", "set -e",
                  "sudo python3 /usr/local/lib/kiln-guard/kiln_guard.py status",
                  'X="$(cat /etc/fstab)"; echo "$X"'):
            self.assertEqual(kind(c), r.READ, c)

    def test_changes(self):
        for c in ("sudo pacman -S vim", "sudo pacman -Syu", "pacman -Rns vim",
                  "paru -S foo", "yay foo", "sudo pacman -Fy", "rm -rf /etc/foo", "touch x",
                  "echo hi > /etc/motd", "echo hi >> ~/.bashrc", "sed -i s/a/b/ f",
                  "systemctl restart sshd", "hyprctl dispatch exit", "hyprctl reload",
                  "wpctl set-volume 60 0.5", "git reset --hard", "git checkout main",
                  "git -c core.pager=x log", "git log --output=/etc/x",
                  "git config user.name x", "find . -delete", "find . -exec rm {} ;",
                  "ip link set eno2 down", "efibootmgr -o 0000",
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

    def test_rescue_pieces(self):
        for c in ("sudo pacman -R linux-cachyos-lts",
                  "sudo pacman -Rns linux-cachyos-lts-nvidia-open",
                  "sudo pacman -Rdd cachyos/limine", "yay -R snapper", "pacman -R snap-pac",
                  "sudo pacman --remove limine-snapper-sync",
                  "sudo systemctl disable --now limine-snapper-sync.service",
                  "sudo systemctl mask snapper-cleanup.timer",
                  "sudo snapper -c root delete 3", "sudo snapper -c home delete-config",
                  "sudo rm -rf /boot/somewhere", "rm /boot/limine.conf", "sudo rm -rf /boot",
                  "sudo btrfs subvolume delete /.snapshots/3/snapshot",
                  "sudo rm -rf /.snapshots/4", "sudo mv /boot/limine.conf /tmp",
                  "echo $(sudo pacman -R limine)"):
            with self.assertRaises(r.Refused, msg=c):
                r.check_rescue_command(c)
        for c in ("ls /boot", "sudo cat /boot/limine.conf", "pacman -Qi linux-cachyos-lts",
                  "sudo pacman -S linux-cachyos-lts", "sudo pacman -Syu", "rm /tmp/boot",
                  "sudo pacman -R vim", "sudo systemctl restart limine-snapper-sync",
                  "sudo snapper -c root list", "sudo systemctl disable bluetooth"):
            r.check_rescue_command(c)

    def test_personal_files(self):
        for c, cwd in (("rm ~/Documents/x.pdf", REPO), ("rm -rf /home/indy/Pictures", REPO),
                       ("rm -rf ~", REPO), ("rm notes.txt", HOME + "/Documents"),
                       ("sudo rm -rf $HOME/Music", REPO), ("rm -rf $SOMEWHERE", REPO),
                       ("find ~/Downloads -name '*.iso' -delete", REPO),
                       ("rsync -a --delete /tmp/x/ ~/Videos/", REPO),
                       ("rm -rf ~/Projects", REPO), ("rm -rf /home/indy/Projects/", REPO),
                       ("gio trash ~/Desktop/a", REPO), ("shred ~/secret.txt", REPO)):
            with self.assertRaises(r.Refused, msg=c):
                r.check_personal_files(c, cwd)
        for c in ("rm -rf build", "rm ~/.cache/foo", "rm -rf ~/.config/old-app",
                  "rm -rf /tmp/claude-%d/x" % os.getuid(), "rm /etc/motd",
                  "rm ~/Projects/kiln/x", "rm -rf ~/Projects/other-project",
                  "rm -rf /home/indy/Projects/a/b.txt", "cp ~/Documents/a /tmp/a", "find ~ -name x",
                  "rsync -a ~/Music/ /tmp/m/"):
            r.check_personal_files(c, REPO)


class Judge(unittest.TestCase):
    def test_description_needed(self):
        with self.assertRaises(r.Refused):
            r.judge({"tool_input": {"command": "sudo pacman -S vim"}, "cwd": REPO})
        with self.assertRaises(r.Refused):
            r.judge({"tool_input": {"command": "sudo pacman -S vim", "description": "pacman"},
                     "cwd": REPO})
        got = r.judge({"tool_input": {"command": "sudo pacman -S vim",
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
        for path in ("/boot/limine.conf", "/.snapshots/6/info.xml"):
            with self.assertRaises(r.Refused):
                file_kind(path)

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
    """The hooks and the log, with snapper and notices replaced."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        r.LOG = self.dir + "/changes.log"
        r.PENDING = self.dir
        r.OPERATOR = self.dir + "/operator.json"
        self.window = (100, "1")
        self.alive = {(100, "1")}
        self.real_proc = r.claude_process, r.process_alive
        self.real_guard = r.guard_blocks
        r.guard_blocks = lambda payload: False
        r.claude_process = lambda: self.window
        r.process_alive = lambda pid, start: (pid, start) in self.alive
        self.count = {"root": 10, "home": 20}
        self.notices = []
        self.real = r.snapper, r.rescue_entry_present, r.notify

        def fake(config, *args):
            self.count[config] += 1
            return str(self.count[config])
        r.snapper = fake
        r.rescue_entry_present = lambda: True
        r.notify = self.notices.append

    def tearDown(self):
        r.snapper, r.rescue_entry_present, r.notify = self.real
        r.claude_process, r.process_alive = self.real_proc
        r.guard_blocks = self.real_guard

    def pre(self, payload):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(r.hook_pre(payload), 0)
        text = out.getvalue()
        return json.loads(text)["hookSpecificOutput"] if text else None

    def run_change(self, tool_id, event="PostToolUse", command="sudo pacman -S vim", **extra):
        payload = {"tool_use_id": tool_id, "cwd": REPO, "hook_event_name": event,
                   "tool_input": {"command": command,
                                  "description": "Install the vim editor", **extra}}
        self.decision = self.pre(payload)
        return payload

    def test_change_runs_without_asking(self):
        self.run_change("a")
        self.assertEqual(self.decision["permissionDecision"], "allow")
        self.assertIn("Snapshot taken", self.decision["permissionDecisionReason"])

    def test_done_then_undoable(self):
        r.hook_post(self.run_change("a"))
        got = r.read_changes(r.LOG)
        self.assertEqual(len(got), 1)
        self.assertEqual((got[0]["root"], got[0]["root2"]), ("11", "12"))
        self.assertEqual((got[0]["home"], got[0]["home2"]), ("21", "22"))
        self.assertEqual(got[0]["said"], "Install the vim editor")

    def test_blocked_later_is_not_undoable(self):
        self.run_change("a")  # The post hook never came.
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

    def test_push_asks_and_has_no_snapshot(self):
        payload = {"tool_use_id": "p", "cwd": REPO, "hook_event_name": "PostToolUse",
                   "tool_input": {"command": "git push", "description": "Send to GitHub"}}
        decision = self.pre(payload)
        r.hook_post(payload)
        self.assertEqual(decision["permissionDecision"], "ask")
        self.assertEqual(self.count, {"root": 10, "home": 20})
        self.assertEqual(r.read_changes(r.LOG), [])

    def test_numbers_count_outward_too(self):
        r.hook_post(self.run_change("a"))
        self.pre({"tool_use_id": "p", "cwd": REPO,
                  "tool_input": {"command": "git push", "description": "Send to GitHub"}})
        r.hook_post(self.run_change("b"))
        self.assertEqual([e["number"] for e in r.read_changes(r.LOG)], [1, 3])

    def test_post_of_a_read_does_nothing(self):
        self.assertEqual(r.hook_post({"tool_use_id": "none"}), 0)

    def test_missing_rescue_kernel_is_reported(self):
        r.rescue_entry_present = lambda: False
        self.assertEqual(r.hook_post(self.run_change("a")), 2)
        self.assertTrue(any("rescue" in n for n in self.notices))

    def test_big_change_sends_a_notice(self):
        r.hook_post(self.run_change("a", command="sudo pacman -Syu"))
        self.assertEqual(len(self.notices), 1)
        r.hook_post(self.run_change("b"))
        self.assertEqual(len(self.notices), 1)


    def test_helper_cannot_change(self):
        payload = {"tool_use_id": "h", "cwd": REPO, "agent_id": "a1", "agent_type": "reviewer",
                   "tool_input": {"command": "sudo pacman -S vim",
                                  "description": "Install the vim editor"}}
        with self.assertRaises(r.Refused):
            r.hook_pre(payload)
        self.assertEqual(self.count, {"root": 10, "home": 20})  # No snapshot taken.

    def test_helper_cannot_push(self):
        payload = {"tool_use_id": "h", "cwd": REPO, "agent_type": "general-purpose",
                   "tool_input": {"command": "git push", "description": "Push to GitHub"}}
        with self.assertRaises(r.Refused):
            r.hook_pre(payload)

    def test_helper_can_read(self):
        payload = {"tool_use_id": "h", "cwd": REPO, "agent_type": "researcher",
                   "tool_input": {"command": "pacman -Qi vim"}}
        self.assertIsNone(self.pre(payload))

    def test_same_window_keeps_working(self):
        self.run_change("a")
        self.run_change("b")
        self.assertEqual(self.decision["permissionDecision"], "allow")

    def test_second_window_is_blocked(self):
        self.run_change("a")
        self.window = (200, "5")
        self.alive.add(self.window)
        with self.assertRaises(r.Refused):
            self.run_change("b")
        self.assertEqual(self.count, {"root": 11, "home": 21})  # Only the first snapshot.

    def test_second_window_takes_over_when_first_closed(self):
        self.run_change("a")
        self.alive.clear()
        self.window = (200, "5")
        self.alive.add(self.window)
        self.run_change("b")
        self.assertEqual(self.decision["permissionDecision"], "allow")

    def test_second_window_takes_over_when_first_idle(self):
        self.run_change("a")
        with open(r.OPERATOR) as f:
            held = json.load(f)
        held["time"] -= r.OPERATOR_IDLE + 1
        with open(r.OPERATOR, "w") as f:
            json.dump(held, f)
        self.window = (200, "5")
        self.alive.add(self.window)
        self.run_change("b")
        self.assertEqual(self.decision["permissionDecision"], "allow")

    def test_reused_pid_is_not_the_same_window(self):
        self.run_change("a")
        self.window = (100, "9")  # Same number, started later: a different process.
        self.alive = {self.window}
        self.run_change("b")
        self.assertEqual(self.decision["permissionDecision"], "allow")


    def test_guard_blocked_leaves_nothing(self):
        r.guard_blocks = lambda payload: True
        self.run_change("a")
        self.assertIsNone(self.decision)
        self.assertEqual(self.count, {"root": 10, "home": 20})  # No snapshot.
        self.assertFalse(os.path.exists(r.LOG))
        self.assertEqual([n for n in os.listdir(self.dir) if n.endswith(".json")], [])

    def test_guard_check_blocks_on_block_or_error(self):
        real = r.kiln_guard.decide, r.kiln_guard.Disks
        try:
            r.kiln_guard.Disks = lambda: None
            r.kiln_guard.decide = lambda payload, disks: None
            self.assertFalse(self.real_guard({}))
            def blocked(payload, disks):
                raise r.kiln_guard.Blocked("no")
            r.kiln_guard.decide = blocked
            self.assertTrue(self.real_guard({}))
            r.kiln_guard.decide = lambda payload, disks: 1 / 0
            self.assertTrue(self.real_guard({}))
        finally:
            r.kiln_guard.decide, r.kiln_guard.Disks = real

    def test_stale_entry_is_closed(self):
        self.run_change("old")  # Its after step never came.
        self.run_change("new")
        path = os.path.join(self.dir, "old.json")
        os.utime(path, (1, 1))
        r.sweep_pending()
        self.assertFalse(os.path.exists(path))
        self.assertTrue(os.path.exists(os.path.join(self.dir, "new.json")))
        with open(r.LOG) as f:
            self.assertIn("#1 NOTRUN", f.read())
        r.hook_post({"tool_use_id": "new", "hook_event_name": "PostToolUse",
                     "tool_input": {"command": "sudo pacman -S vim"}})
        self.assertEqual([e["number"] for e in r.read_changes(r.LOG)], [2])


class Session(unittest.TestCase):
    def test_summary_since_last_session(self):
        folder = tempfile.mkdtemp()
        r.LOG, r.LAST_SESSION = folder + "/changes.log", folder + "/last"
        r.PACMAN_LOG = folder + "/pacman.log"
        r.WATCH_REPORT = folder + "/latest.txt"
        r.SENTRY_REPORT = folder + "/sentry.txt"
        r.PENDING = folder
        with open(r.SENTRY_REPORT, "w") as f:
            f.write("Kiln sentry, 2026-11-13 12:00: clear.\n")
        with open(r.WATCH_REPORT, "w") as f:
            f.write("Kiln watch, 2026-11-13 12:00: 1 thing needs attention.\n\n"
                    "NEEDS ATTENTION: Failed services: foo.service.\n")
        with open(r.LAST_SESSION, "w") as f:
            f.write("2026-11-13 12:00\n")
        with open(r.LOG, "w") as f:
            f.write("2026-11-13 11:00  #1 CHANGE [root 1 home 1] Old one\n")
            f.write("    command: x\n")
            f.write("2026-11-13 13:00  #2 CHANGE [root 3 home 3] New one\n")
        with open(r.PACMAN_LOG, "w") as f:
            f.write("[2026-11-13T11:30:00+0000] [ALPM] upgraded old (1 -> 2)\n")
            f.write("[2026-11-13T12:30:00+0000] [ALPM] upgraded vim (1 -> 2)\n")
            f.write("[2026-11-13T12:30:00+0000] [PACMAN] Running x\n")
        out = io.StringIO()
        with redirect_stdout(out):
            r.hook_session({"source": "startup"})
        text = out.getvalue()
        self.assertIn("New one", text)
        self.assertNotIn("Old one", text)
        self.assertIn("upgraded vim", text)
        self.assertIn("Kiln sentry, 2026-11-13 12:00: clear.", text)
        self.assertIn("NEEDS ATTENTION: Failed services: foo.service.", text)
        self.assertNotIn("upgraded old", text)
        with open(r.LAST_SESSION) as f:
            self.assertNotEqual(f.read().strip(), "2026-11-13 12:00")


class Undo(unittest.TestCase):
    def test_changes_before_a_restore_cannot_be_undone(self):
        folder = tempfile.mkdtemp()
        r.LOG = folder + "/changes.log"
        with open(r.LOG, "w") as f:
            f.write("2026-11-03 10:00  #1 CHANGE [root 11 home 11] Before\n")
            f.write("2026-11-03 10:00  #1 DONE [root 12 home 12]\n")
            f.write("2026-11-03 10:01  #0 RESTORED to snapshot 6\n")
            f.write("2026-11-03 10:02  #2 CHANGE [root 13 home 13] After\n")
            f.write("2026-11-03 10:02  #2 DONE [root 14 home 14]\n")
        self.assertEqual([e["number"] for e in r.read_changes(r.LOG)], [2])

    def test_a_change_that_changed_nothing_is_skipped(self):
        folder = tempfile.mkdtemp()
        r.LOG = folder + "/changes.log"
        for number, root in ((1, 11), (2, 13)):
            with open(r.LOG, "a") as f:
                f.write("2026-11-03 10:00  #%d CHANGE [root %d home %d] Change %d\n"
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
