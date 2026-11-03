#!/usr/bin/python3
"""Plants wrongly built packages in a fake system, and checks the audit catches each one."""
import bz2
import os
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import flags_audit as a

ELF = b"\x7fELF\x02\x01\x01\x00"


class Audit(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()

    def package(self, name, cflags="-O2 -march=native", code=True, ready=False, inherited="",
                environment="", recipe="", archive=False):
        """A fake installed package."""
        folder = os.path.join(self.root, "var/db/pkg", name)
        os.makedirs(folder)
        installed = "/usr/lib64/%s.so" % name.replace("/", "_")
        full = self.root + installed
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as f:
            if not code:
                f.write(b"plain text")
            else:
                f.write(b"!<arch>\n" if archive else ELF)
        files = {"CONTENTS": "dir /usr\nobj %s abc 123\n" % installed, "CFLAGS": cflags,
                 "INHERITED": inherited}
        if ready:
            files["BINPKGMD5"] = "abc"
        if recipe:
            files[os.path.basename(name) + ".ebuild"] = recipe
        for file_name, text in files.items():
            with open(os.path.join(folder, file_name), "w") as f:
                f.write(text)
        with bz2.open(os.path.join(folder, "environment.bz2"), "wt") as f:
            f.write(environment)

    def results(self, exceptions=None):
        return {r[0]: r for r in a.audit(self.root, exceptions or {})}

    def result(self, name, exceptions=None):
        return self.results(exceptions)[name][1]

    def test_built_here_for_this_cpu_passes(self):
        self.package("app/good-1.0")
        self.assertEqual(self.result("app/good-1.0"), a.NATIVE)

    def test_planted_generic_build_is_caught(self):
        self.package("app/planted-1.0", cflags="-O2 -march=x86-64")
        self.assertEqual(self.result("app/planted-1.0"), a.BUILT_WRONG)

    def test_this_cpu_spelled_out_in_full_passes(self):
        self.package("sys-devel/gcc-16", cflags="-O3 -march=alderlake -mabm -mno-kl -mno-sgx -mno-widekl -mshstk")
        self.assertEqual(self.result("sys-devel/gcc-16"), a.NATIVE)

    def test_gcc_recipe_limit_passes_with_a_warning(self):
        self.package("sys-devel/gcc-16.2.1_p20260926", cflags="-pipe -march=alderlake -O3")
        got = self.results()["sys-devel/gcc-16.2.1_p20260926"]
        self.assertEqual(got[1], a.NATIVE)
        self.assertIn("recipe keeps only", got[3])

    def test_a_near_miss_of_this_cpu_is_caught(self):
        self.package("app/planted-1.0", cflags="-O3 -march=alderlake")
        self.assertEqual(self.result("app/planted-1.0"), a.BUILT_WRONG)

    def test_planted_build_with_no_march_is_caught(self):
        self.package("app/planted-1.0", cflags="-O2")
        self.assertEqual(self.result("app/planted-1.0"), a.BUILT_WRONG)

    def test_ready_built_is_not_counted_as_native_even_with_native_flags(self):
        self.package("app/sneaky-1.0", cflags="-march=native", ready=True)
        self.assertEqual(self.result("app/sneaky-1.0"), a.READY)

    def test_planted_rust_without_this_cpu_is_caught(self):
        self.package("app/rusty-1.0", inherited="cargo",
                     environment='declare -x RUSTFLAGS="-C opt-level=3"\n')
        self.assertEqual(self.result("app/rusty-1.0"), a.RUST_WRONG)

    def test_rust_with_this_cpu_passes(self):
        self.package("app/rusty-1.0", inherited="cargo",
                     environment='declare -x RUSTFLAGS="-C target-cpu=native"\n')
        self.assertEqual(self.result("app/rusty-1.0"), a.NATIVE)

    def test_planted_go_below_v3_is_caught(self):
        self.package("app/gopher-1.0", inherited="go-module", environment='declare -x GOAMD64="v1"\n')
        self.assertEqual(self.result("app/gopher-1.0"), a.GO_WRONG)

    def test_go_with_no_level_is_caught(self):
        self.package("app/gopher-1.0", inherited="go-env")
        self.assertEqual(self.result("app/gopher-1.0"), a.GO_WRONG)

    def test_go_at_v3_passes(self):
        self.package("app/gopher-1.0", inherited="go-module", environment='declare -x GOAMD64="v3"\n')
        self.assertEqual(self.result("app/gopher-1.0"), a.NATIVE)

    def test_no_compiled_code_is_not_held_against_it(self):
        self.package("virtual/thing-1", code=False, cflags="")
        self.assertEqual(self.result("virtual/thing-1"), a.NO_CODE)

    def test_a_static_library_counts_as_code(self):
        self.package("app/lib-1.0", cflags="-march=x86-64", archive=True)
        self.assertEqual(self.result("app/lib-1.0"), a.BUILT_WRONG)

    def test_exception_is_listed_with_its_reason(self):
        self.package("vendor/blob-1.2.3-r1", ready=True, cflags="")
        got = self.results({"vendor/blob": "Supplied ready-built"})["vendor/blob-1.2.3-r1"]
        self.assertEqual(got[1:3], (a.EXCEPTION, "Supplied ready-built"))

    def test_recipe_that_may_change_flags_gets_a_warning(self):
        self.package("app/filtered-1.0", recipe="src_configure() { strip-flags; }\n")
        self.assertEqual(self.results()["app/filtered-1.0"][3], "recipe may change its flags")

    def test_report_counts_and_names_problems(self):
        self.package("app/good-1.0")
        self.package("app/planted-1.0", cflags="-march=x86-64")
        text = a.report(a.audit(self.root, {}), [(False, "a failed proof")])
        self.assertIn("1 of 2 with compiled code, 50.0%", text)
        self.assertIn("app/planted-1.0: built-here-not-native, x86-64", text)
        self.assertIn("FAIL a failed proof", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
