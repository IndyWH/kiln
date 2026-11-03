#!/usr/bin/python3
"""Tests for the boot menu and restore, on fake folders. Nothing real is touched."""
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
sys.path[:0] = [os.path.join(ROOT, "guard"), os.path.join(ROOT, "sidekick")]
import kiln_snapshots as menu

VERSION = "6.18.60-gentoo-mlrig"
MLRIG = """title      Gentoo Linux
version    6.18.60-gentoo-mlrig
sort-key   gentoo
options    root=LABEL=KILN-ROOT rootflags=subvol=@ rw rd.lvm=0
linux      /id/6.18.60-gentoo-mlrig/linux
initrd     /id/6.18.60-gentoo-mlrig/microcode-intel
initrd     /id/6.18.60-gentoo-mlrig/initrd
"""
RESCUE = MLRIG.replace("mlrig", "dist-bin")
RESCUE_VERSION = "6.18.60-gentoo-dist-bin"


class Base(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        menu.SNAPSHOTS = self.dir + "/snapshots"
        menu.ENTRIES = self.dir + "/entries"
        menu.CMDLINE = self.dir + "/cmdline"
        os.makedirs(menu.SNAPSHOTS)
        os.makedirs(menu.ENTRIES)
        self.write(menu.CMDLINE, "root=LABEL=KILN-ROOT rootflags=subvol=@ rw\n")
        self.write(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf", MLRIG)
        self.write(menu.ENTRIES + "/id-6.18.60-gentoo-dist-bin.conf", RESCUE)

    @staticmethod
    def write(path, text=""):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def snapshot(self, number, kind="single", guard=True, modules=True, words="a test",
                 milestone=False, rescue_modules=True):
        base = "%s/%d" % (menu.SNAPSHOTS, number)
        extra = ("<userdata><key>milestone</key><value>yes</value></userdata>"
                 if milestone else "")
        self.write(base + "/info.xml", "<snapshot><type>%s</type><num>%d</num>"
                   "<date>2026-11-03 10:25:38</date><description>%s</description>%s</snapshot>"
                   % (kind, number, words, extra))
        os.makedirs(base + "/snapshot/usr")
        if guard:
            for f in menu.GUARD_FILES:
                self.write("%s/snapshot/%s" % (base, f))
        if modules:
            os.makedirs("%s/snapshot/usr/lib/modules/%s" % (base, VERSION))
        if rescue_modules:
            os.makedirs("%s/snapshot/usr/lib/modules/%s" % (base, RESCUE_VERSION))

    def names(self):
        return sorted(f for f in os.listdir(menu.ENTRIES) if f.startswith(menu.PREFIX))


class Menu(Base):
    def test_entry_boots_the_snapshot_read_only(self):
        self.snapshot(7, words="before: a change")
        self.assertEqual(menu.cmd_menu(), 0)
        with open(menu.ENTRIES + "/kiln-snapshot-00007.conf") as f:
            text = f.read()
        self.assertIn("rootflags=subvol=@snapshots/7/snapshot ro rd.lvm=0", text)
        self.assertNotIn(" rw", text)
        self.assertIn("linux      /id/6.18.60-gentoo-mlrig/linux", text)
        self.assertIn("initrd     /id/6.18.60-gentoo-mlrig/microcode-intel", text)
        self.assertIn("sort-key   kiln-snapshot", text)
        self.assertIn("before: a change (read-only)", text)

    def test_keeps_the_newest_five(self):
        for number in range(1, 9):
            self.snapshot(number)
        menu.cmd_menu()
        self.assertEqual(self.names(), ["kiln-snapshot-%05d.conf" % n for n in range(4, 9)])

    def test_old_milestones_stay_beside_the_newest_five(self):
        self.snapshot(1, milestone=True, words="oldest mark")
        self.snapshot(2, milestone=True)
        self.snapshot(3, milestone=True)
        self.snapshot(4, milestone=True, words="newest old mark")
        for number in range(5, 13):
            self.snapshot(number)
        menu.cmd_menu()
        self.assertEqual(self.names(), ["kiln-snapshot-%05d.conf" % n for n in
                                        (2, 3, 4, 8, 9, 10, 11, 12)])
        with open(menu.ENTRIES + "/kiln-snapshot-00004.conf") as f:
            self.assertIn("title      Milestone 4, ", f.read())

    def test_a_new_milestone_is_not_listed_twice(self):
        self.snapshot(1)
        self.snapshot(2, milestone=True)
        menu.cmd_menu()
        self.assertEqual(self.names(), ["kiln-snapshot-00001.conf", "kiln-snapshot-00002.conf"])

    def test_unsafe_or_unsuitable_snapshots_are_left_out(self):
        self.snapshot(1, guard=False, milestone=True)
        self.snapshot(2, modules=False)
        self.snapshot(3, kind="post")
        self.snapshot(4, kind="pre")
        menu.cmd_menu()
        self.assertEqual(self.names(), ["kiln-snapshot-00004.conf"])

    def test_half_made_snapshot_is_skipped(self):
        os.makedirs(menu.SNAPSHOTS + "/9")
        self.assertEqual(menu.cmd_menu(), 0)
        self.assertEqual(self.names(), [])

    def test_removed_snapshot_leaves_the_menu(self):
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        menu.cmd_menu()
        self.assertEqual(self.names(), ["kiln-snapshot-00003.conf"])

    def test_kernel_entries_are_never_touched(self):
        self.snapshot(3)
        menu.cmd_menu()
        with open(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf") as f:
            self.assertEqual(f.read(), MLRIG)
        with open(menu.ENTRIES + "/id-6.18.60-gentoo-dist-bin.conf") as f:
            self.assertEqual(f.read(), RESCUE)

    def test_nothing_changes_while_booted_from_a_snapshot(self):
        self.write(menu.CMDLINE, "rootflags=subvol=@snapshots/7/snapshot ro\n")
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        self.assertEqual(menu.cmd_menu(), 0)
        self.assertEqual(self.names(), ["kiln-snapshot-00002.conf"])

    def test_no_kernel_leaves_the_menu_alone(self):
        os.unlink(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf")
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        self.assertEqual(menu.cmd_menu(), 1)
        self.assertEqual(self.names(), ["kiln-snapshot-00002.conf"])

    def test_default_pattern_does_not_match_a_snapshot(self):
        self.assertNotRegex(menu.PREFIX + "00026.conf", "-mlrig")


class Restore(Base):
    """The swap, with a plain folder standing in for the filesystem's top level."""

    def setUp(self):
        super().setUp()
        self.top = self.dir + "/top"
        os.makedirs(self.top + "/@")
        self.write(self.top + "/@/now", "current system")
        self.real_run = menu.run

        def fake_run(*command):
            if command[:3] != ("btrfs", "subvolume", "snapshot"):
                raise AssertionError("unexpected command: %r" % (command,))
            os.makedirs(command[4])
            with open(command[4] + "/now", "w") as f:
                f.write("past system")
            return ""
        menu.run = fake_run

    def tearDown(self):
        menu.run = self.real_run

    def now(self):
        with open(self.top + "/@/now") as f:
            return f.read()

    def test_restore_then_back(self):
        aside = menu.do_restore(self.top, 7)
        self.assertEqual(self.now(), "past system")
        self.assertEqual(menu.old_systems(self.top), [aside])
        with open(os.path.join(self.top, aside, "now")) as f:
            self.assertEqual(f.read(), "current system")
        back_to, newest_aside = menu.do_back(self.top)
        self.assertEqual(back_to, aside)
        self.assertEqual(self.now(), "current system")
        self.assertEqual(menu.old_systems(self.top), [newest_aside])

    def test_nothing_set_aside_means_no_back(self):
        with self.assertRaises(menu.RestoreError):
            menu.do_back(self.top)
        self.assertEqual(self.now(), "current system")

    def test_failed_swap_puts_the_system_back(self):
        with self.assertRaises(OSError):
            menu.swap(self.top, "@.missing")
        self.assertEqual(self.now(), "current system")
        self.assertEqual(menu.old_systems(self.top), [])

    def test_failed_copy_changes_nothing(self):
        def broken(*command):
            raise menu.RestoreError("btrfs failed")
        menu.run = broken
        with self.assertRaises(menu.RestoreError):
            menu.do_restore(self.top, 7)
        self.assertEqual(self.now(), "current system")

    def test_a_snapshot_must_hold_every_kernels_drivers(self):
        self.snapshot(1, rescue_modules=False)
        self.snapshot(2)
        self.assertEqual([s["number"] for s in menu.restorable()], [2])

    def test_no_kernels_stops_restore(self):
        os.unlink(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf")
        os.unlink(menu.ENTRIES + "/id-6.18.60-gentoo-dist-bin.conf")
        with self.assertRaises(menu.RestoreError):
            menu.restorable()


if __name__ == "__main__":
    unittest.main(verbosity=1)
