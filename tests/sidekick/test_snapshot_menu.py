#!/usr/bin/python3
"""Tests for the boot menu program, on fake folders. Nothing real is touched."""
import importlib.machinery
import importlib.util
import os
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
loader = importlib.machinery.SourceFileLoader(
    "menu", os.path.join(ROOT, "config/usr/local/bin/kiln-snapshot-menu"))
spec = importlib.util.spec_from_loader("menu", loader)
menu = importlib.util.module_from_spec(spec)
loader.exec_module(menu)

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


class Menu(unittest.TestCase):
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

    def snapshot(self, number, kind="single", guard=True, modules=True, words="a test"):
        base = "%s/%d" % (menu.SNAPSHOTS, number)
        self.write(base + "/info.xml", "<snapshot><type>%s</type><num>%d</num>"
                   "<date>2026-11-03 10:25:38</date><description>%s</description></snapshot>"
                   % (kind, number, words))
        os.makedirs(base + "/snapshot/usr")
        if guard:
            for f in menu.GUARD_FILES:
                self.write("%s/snapshot/%s" % (base, f))
        if modules:
            os.makedirs("%s/snapshot/usr/lib/modules/%s" % (base, VERSION))

    def names(self):
        return sorted(f for f in os.listdir(menu.ENTRIES) if f.startswith(menu.PREFIX))

    def test_entry_boots_the_snapshot_read_only(self):
        self.snapshot(7, words="before: a change")
        self.assertEqual(menu.main(), 0)
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
        menu.main()
        self.assertEqual(self.names(), ["kiln-snapshot-%05d.conf" % n for n in range(4, 9)])

    def test_unsafe_or_unsuitable_snapshots_are_left_out(self):
        self.snapshot(1, guard=False)
        self.snapshot(2, modules=False)
        self.snapshot(3, kind="post")
        self.snapshot(4, kind="pre")
        menu.main()
        self.assertEqual(self.names(), ["kiln-snapshot-00004.conf"])

    def test_half_made_snapshot_is_skipped(self):
        os.makedirs(menu.SNAPSHOTS + "/9")
        self.assertEqual(menu.main(), 0)
        self.assertEqual(self.names(), [])

    def test_removed_snapshot_leaves_the_menu(self):
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        menu.main()
        self.assertEqual(self.names(), ["kiln-snapshot-00003.conf"])

    def test_kernel_entries_are_never_touched(self):
        self.snapshot(3)
        menu.main()
        with open(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf") as f:
            self.assertEqual(f.read(), MLRIG)
        with open(menu.ENTRIES + "/id-6.18.60-gentoo-dist-bin.conf") as f:
            self.assertEqual(f.read(), RESCUE)

    def test_nothing_changes_while_booted_from_a_snapshot(self):
        self.write(menu.CMDLINE, "rootflags=subvol=@snapshots/7/snapshot ro\n")
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        self.assertEqual(menu.main(), 0)
        self.assertEqual(self.names(), ["kiln-snapshot-00002.conf"])

    def test_no_kernel_leaves_the_menu_alone(self):
        os.unlink(menu.ENTRIES + "/id-6.18.60-gentoo-mlrig.conf")
        self.write(menu.ENTRIES + "/kiln-snapshot-00002.conf", "old")
        self.snapshot(3)
        self.assertEqual(menu.main(), 1)
        self.assertEqual(self.names(), ["kiln-snapshot-00002.conf"])

    def test_default_pattern_does_not_match_a_snapshot(self):
        self.assertNotRegex(menu.PREFIX + "00026.conf", "-mlrig")


if __name__ == "__main__":
    unittest.main(verbosity=1)
