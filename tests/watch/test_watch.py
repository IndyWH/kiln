#!/usr/bin/python3
"""Tests for kiln-watch: a new NVIDIA driver among the waiting updates is flagged before install."""
import importlib.machinery
import importlib.util
import os
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.realpath(__file__))
PATH = os.path.join(HERE, "..", "..", "scripts", "kiln-watch")
loader = importlib.machinery.SourceFileLoader("kiln_watch", PATH)
spec = importlib.util.spec_from_loader("kiln_watch", loader)
w = importlib.util.module_from_spec(spec)
loader.exec_module(w)

KILN = ["7.3.4-1-cachyos-kiln", "7.3.4-1-cachyos"]
STOCK = ["7.3.4-1-cachyos", "6.18.60-2-cachyos-lts"]


class DriverWaiting(unittest.TestCase):
    def check(self, lines, modules=KILN):
        r = w.Report()
        with mock.patch.object(w.os, "listdir", return_value=modules):
            w.check_driver_waiting(r, lines)
        return r.attention

    def test_new_driver_flagged(self):
        found = self.check(["mesa 3:26.2.6-1 -> 3:26.3.1-4",
                            "nvidia-utils 620.70.06-2 -> 620.75.02-1"])
        self.assertEqual(len(found), 1)
        self.assertIn("620.75.02", found[0])
        self.assertIn("620.70.06", found[0])
        self.assertIn("kernel/rebuild.sh", found[0])

    def test_same_driver_new_release_not_flagged(self):
        self.assertEqual(self.check(["nvidia-utils 620.70.06-2 -> 620.70.06-3"]), [])

    def test_other_nvidia_packages_ignored(self):
        self.assertEqual(self.check(["nvidia-settings 620.70.06-1 -> 620.75.02-1",
                                     "lib32-nvidia-utils 620.70.06-1 -> 620.75.02-1"]), [])

    def test_no_kiln_kernel_no_warning(self):
        self.assertEqual(self.check(["nvidia-utils 620.70.06-2 -> 620.75.02-1"], STOCK), [])

    def test_no_updates(self):
        self.assertEqual(self.check([]), [])


if __name__ == "__main__":
    unittest.main()
