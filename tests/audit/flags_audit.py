#!/usr/bin/python3
"""Kiln Linux: the flags audit. How was every installed program really built?

Reads Portage's records in /var/db/pkg and looks inside each package for compiled code.
Writes nothing unless given --save. Run it after every update.

Levels of evidence, kept apart on purpose:
  asked   Portage's record of the settings a build was given. A recipe can still change them.
  proved  Evidence from the built files themselves, for a sample of important programs.
"""
import bz2
import collections
import glob
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
# Recipes that may change the flags they are given.
CHANGES_FLAGS = re.compile(r"\b(?:strip-flags|filter-flags|filter-march|replace-cpu-flags"
                           r"|replace-flags|strip-unsupported-flags)\b")

# This CPU, spelled out, for GCC itself, which refuses -march=native on a hybrid chip.
SAME_AS_NATIVE = ("-march=alderlake", "-mabm", "-mno-kl", "-mno-sgx", "-mno-widekl", "-mshstk")

# GCC refuses -march=native here, and these recipes strip the rest of that list.
RECIPE_LIMITED = {"sys-devel/gcc": "alderlake", "sys-devel/binutils": "alderlake"}

# The result for each package. "ok" means built for this CPU as far as records show.
NATIVE, READY, BUILT_WRONG, RUST_WRONG, GO_WRONG, EXCEPTION, NO_CODE = (
    "native", "ready-built", "built-here-not-native", "rust-without-this-cpu",
    "go-below-v3", "exception", "no-compiled-code")


def read_file(path):
    try:
        with open(path, errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def has_compiled_code(package_dir, root):
    """True if the package installed an ELF file or a static library."""
    for line in read_file(os.path.join(package_dir, "CONTENTS")).splitlines():
        if not line.startswith("obj "):
            continue
        # obj /path/with spaces md5 mtime
        path = line[4:].rsplit(" ", 2)[0]
        try:
            with open(root.rstrip("/") + path, "rb") as f:
                if f.read(8)[:4] == b"\x7fELF" or f.seek(0) == 0 and f.read(8) == b"!<arch>\n":
                    return True
        except OSError:
            continue
    return False


def build_setting(package_dir, name):
    """A setting from the build's saved environment, such as RUSTFLAGS."""
    try:
        with bz2.open(os.path.join(package_dir, "environment.bz2"), "rt", errors="replace") as f:
            for line in f:
                match = re.match(r'declare -x %s="(.*)"$' % re.escape(name), line.rstrip("\n"))
                if match:
                    return match.group(1)
    except OSError:
        pass
    return ""


def read_exceptions(path):
    """Lines of: category/name reason. These can never be built for this CPU here."""
    found = {}
    for line in read_file(path).splitlines():
        if line.strip() and not line.startswith("#"):
            name, _, reason = line.partition(" ")
            found[name] = reason.strip()
    return found


def classify(package_dir, root, exceptions):
    """Returns (result, detail, warning) for one installed package."""
    name = re.sub(r"-[0-9].*$", "", os.path.relpath(package_dir, os.path.join(package_dir, "..", "..")))
    if not has_compiled_code(package_dir, root):
        return NO_CODE, "", ""
    if name in exceptions:
        return EXCEPTION, exceptions[name], ""

    cflags = read_file(os.path.join(package_dir, "CFLAGS"))
    inherited = read_file(os.path.join(package_dir, "INHERITED")).split()
    ready_built = os.path.exists(os.path.join(package_dir, "BINPKGMD5"))
    march = re.search(r"-march=(\S+)", cflags)
    march = march.group(1) if march else "none recorded"
    if ready_built:
        return READY, march, ""

    if "cargo" in inherited:
        rustflags = build_setting(package_dir, "RUSTFLAGS")
        if "target-cpu=native" not in rustflags:
            return RUST_WRONG, rustflags or "no RUSTFLAGS", ""
    if {"go-module", "go-env"} & set(inherited):
        level = build_setting(package_dir, "GOAMD64")
        if level not in ("v3", "v4"):
            return GO_WRONG, level or "no GOAMD64", ""
    if name in RECIPE_LIMITED and march == RECIPE_LIMITED[name]:
        return NATIVE, "", "recipe keeps only -march=%s" % march
    if march != "native" and not all(flag in cflags.split() for flag in SAME_AS_NATIVE):
        return BUILT_WRONG, march, ""

    recipe = read_file(glob.glob(os.path.join(package_dir, "*.ebuild"))[0]) if glob.glob(
        os.path.join(package_dir, "*.ebuild")) else ""
    warning = "recipe may change its flags" if CHANGES_FLAGS.search(recipe) else ""
    return NATIVE, "", warning


def audit(root="/", exceptions=None):
    exceptions = {} if exceptions is None else exceptions
    results = []
    for package_dir in sorted(glob.glob(os.path.join(root, "var/db/pkg/*/*"))):
        if not os.path.exists(os.path.join(package_dir, "CONTENTS")):
            continue
        name = os.path.relpath(package_dir, os.path.join(root, "var/db/pkg"))
        result, detail, warning = classify(package_dir, root, exceptions)
        results.append((name, result, detail, warning))
    return results


def contains(path, word):
    try:
        output = subprocess.run(["strings", path], capture_output=True, text=True, check=False).stdout
    except OSError:
        return False
    return word in output


def proofs():
    """Evidence from built files, for the things that matter most. A sample, not all."""
    lines = []
    for folder in sorted(glob.glob("/usr/src/kiln-kernel/*/init") + ["/usr/src/linux/init"]):
        record = os.path.join(folder, ".main.o.cmd")
        if os.path.exists(record):
            text = read_file(record)
            lines.append(("-march=native" in text, "kernel %s: build record of init/main.c has -march=native"
                          % os.path.basename(os.path.dirname(os.path.realpath(folder)))))
    for path, word, what in (
            (glob.glob("/usr/lib*/python*/site-packages/torch/lib/libtorch_cuda.so"), "-arch sm_89",
             "PyTorch: GPU code is for this GPU's generation, sm_89"),
            (glob.glob("/usr/lib*/python*/site-packages/torchvision/_C*.so"), "-arch sm_89",
             "torchvision: GPU code is for this GPU's generation, sm_89")):
        if path:
            lines.append((contains(path[0], word), what))
    return lines


def report(results, proved):
    with_code = [r for r in results if r[1] != NO_CODE]
    counts = collections.Counter(r[1] for r in results)
    native = counts[NATIVE]
    lines = ["Kiln flags audit, %s" % time.strftime("%Y-%m-%d %H:%M"),
             "", "%d packages installed, %d with compiled code." % (len(results), len(with_code)),
             "Built for this CPU, as asked: %d of %d with compiled code, %.1f%%."
             % (native, len(with_code), 100.0 * native / max(len(with_code), 1)),
             "", "Results:"]
    for result in (NATIVE, READY, BUILT_WRONG, RUST_WRONG, GO_WRONG, EXCEPTION, NO_CODE):
        lines.append("  %-24s %d" % (result, counts[result]))
    lines += ["", "Ready-built, by the level they were built for:"]
    for level, count in collections.Counter(r[2] for r in results if r[1] == READY).most_common():
        lines.append("  %-24s %d" % (level, count))

    problems = [r for r in results if r[1] in (BUILT_WRONG, RUST_WRONG, GO_WRONG)]
    lines += ["", "Compiled here, but not for this CPU: %d" % len(problems)]
    lines += ["  %s: %s, %s" % (r[0], r[1], r[2]) for r in problems]
    lines += ["", "Exceptions, which cannot be built for this CPU:"]
    lines += ["  %s: %s" % (r[0], r[2]) for r in results if r[1] == EXCEPTION]
    warned = [r for r in results if r[3]]
    lines += ["", "Built for this CPU as asked, with a warning: %d" % len(warned)]
    lines += ["  %s: %s" % (r[0], r[3]) for r in warned]
    lines += ["", "Proved from the built files, a sample only:"]
    lines += ["  %s %s" % ("PASS" if ok else "FAIL", what) for ok, what in proved]
    lines += ["", "Not in Portage, so not counted above:",
              "  Claude Code in ~/.local/bin: ready-built by Anthropic",
              "  NVIDIA modules for extra kernels: built by scripts/build-nvidia.sh"]
    return "\n".join(lines)


def main(argv):
    results = audit("/", read_exceptions(os.path.join(HERE, "exceptions.txt")))
    text = report(results, proofs())
    print(text)
    if "--save" in argv:
        folder = os.path.join(ROOT, "results", "flags-audit")
        os.makedirs(folder, exist_ok=True)
        stamp = time.strftime("%Y-%m-%d-%H%M")
        with open(os.path.join(folder, stamp + ".txt"), "w") as f:
            f.write(text + "\n\nEvery package:\n")
            for name, result, detail, warning in results:
                f.write("%s\t%s\t%s\t%s\n" % (name, result, detail, warning))
    return 1 if any(r[1] in (BUILT_WRONG, RUST_WRONG, GO_WRONG) for r in results) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
