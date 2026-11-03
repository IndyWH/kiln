#!/usr/bin/python3
"""Checks the settings in config/ on this machine. Temp files only, in memory.

Reads the settings with Portage's own parser, then compiles and runs a test
program with those exact flags, on fast and efficient cores, with and without
the step 11 rebuild settings. Prints PASS or FAIL. Exit 0 means all passed.
"""
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from portage.util import getconfig  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "..", "..", "config", "portage")
# First and last of the fast threads, then of the efficient threads.
THREADS = (0, 8, 15, 16, 31)
fails = 0


def check(name, ok, detail=""):
    global fails
    print("%s  %s%s" % ("PASS" if ok else "FAIL", name, " (%s)" % detail if detail and not ok else ""))
    fails += 0 if ok else 1


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def read(tmp, with_rebuild):
    """Portage's parser, on a copy of make.conf with the step 11 line as asked."""
    text = open(os.path.join(CONFIG, "make.conf")).read()
    line = "# source /etc/portage/rebuild.conf"
    check("make.conf has the step 11 line, switched off", line in text)
    if with_rebuild:
        text = text.replace(line, "source " + os.path.join(CONFIG, "rebuild.conf"))
    path = os.path.join(tmp, "make.conf")
    with open(path, "w") as f:
        f.write(text)
    return getconfig(path, tolerant=False, allow_sourcing=True, expand=True)


def compile_and_run(tmp, conf, label):
    binary = os.path.join(tmp, "march_test")
    if os.path.exists(binary):
        os.remove(binary)
    flags = shlex.split(conf["CFLAGS"]) + shlex.split(conf.get("LDFLAGS", ""))
    built = run("gcc", *flags, os.path.join(HERE, "march_test.c"), "-o", binary)
    check("%s: compiles with these exact flags" % label, built.returncode == 0, built.stderr[:300])
    if built.returncode:
        return
    for t in THREADS:
        result = run("taskset", "-c", str(t), binary)
        check("%s: runs on thread %d" % (label, t),
              result.returncode == 0 and result.stdout.startswith("thread %d ok" % t),
              result.stdout + result.stderr)


def check_rust(tmp, conf):
    flags = shlex.split(conf.get("RUSTFLAGS", ""))
    check("Rust targets this exact CPU", "target-cpu=native" in flags)
    if not shutil.which("rustc"):
        print("SKIP  Rust is not installed, so nothing was compiled")
        return
    binary = os.path.join(tmp, "rust_test")
    built = run("rustc", *flags, os.path.join(HERE, "rust_test.rs"), "-o", binary)
    check("Rust: compiles with these flags, and knows this chip's features",
          built.returncode == 0, built.stderr[:300])
    if built.returncode:
        return
    for t in THREADS:
        result = run("taskset", "-c", str(t), binary)
        check("Rust: runs on thread %d" % t, result.returncode == 0 and result.stdout.strip() == "ok",
              result.stdout + result.stderr)
    features = run("rustc", *flags, "--print", "cfg").stdout
    check("Rust leaves out AVX-512, which this chip does not have", "avx512" not in features)


def check_go(tmp, conf):
    """Go has only broad levels, so v3 is the most this chip can use."""
    level = conf.get("GOAMD64", "")
    check("Go uses level v3", level == "v3", level)
    with open("/proc/cpuinfo") as f:
        cpu = next(line for line in f if line.startswith("flags")).split()
    check("This chip has what v3 needs", {"avx2", "bmi1", "bmi2", "fma", "movbe"} <= set(cpu))
    check("This chip does not have what v4 needs", "avx512f" not in cpu)
    if not shutil.which("go"):
        print("SKIP  Go is not installed, so nothing was compiled")
        return
    source = os.path.join(tmp, "go_test.go")
    with open(source, "w") as f:
        f.write('package main\nimport "fmt"\nfunc main() { fmt.Println("ok") }\n')
    binary = os.path.join(tmp, "go_test")
    env = dict(os.environ, GOAMD64=level, GOCACHE=os.path.join(tmp, "go-cache"))
    built = subprocess.run(["go", "build", "-o", binary, source],
                           capture_output=True, text=True, env=env)
    check("Go: compiles at this level", built.returncode == 0, built.stderr[:300])
    if built.returncode == 0:
        for t in THREADS:
            result = run("taskset", "-c", str(t), binary)
            check("Go: runs on thread %d" % t, result.stdout.strip() == "ok")


def enabled(march):
    out = run("gcc", "-march=" + march, "-Q", "--help=target").stdout
    return {line.split()[0] for line in out.splitlines()
            if line.split()[-1:] == ["[enabled]"] and line.strip().startswith("-m")}


def main():
    print("Compiler:", run("gcc", "--version").stdout.splitlines()[0])
    tmp = tempfile.mkdtemp(prefix="kiln-build-check-")
    try:
        base = read(tmp, False)
        check("Base flags have -march=native, and no LTO",
              "-march=native" in base["CFLAGS"] and "-flto" not in base["CFLAGS"])
        check("Base has no lto or pgo", not {"lto", "pgo"} & set(base.get("USE", "").split()))
        check("Builds run on the @cache section",
              base["PORTAGE_TMPDIR"].startswith("/var/cache/"))

        found = run("cpuid2cpuflags").stdout.split(":", 1)[1].split()
        check("CPU flags match cpuid2cpuflags on this chip",
              sorted(found) == sorted(base["CPU_FLAGS_X86"].split()))

        compile_and_run(tmp, base, "Base")
        check_rust(tmp, base)
        check_go(tmp, base)

        rebuild = read(tmp, True)
        check("Rebuild keeps Rust on this CPU, with Full LTO",
              "target-cpu=native" in rebuild.get("RUSTFLAGS", "")
              and rebuild.get("CARGO_PROFILE_RELEASE_LTO") == "fat")
        check("Rebuild keeps Go at v3", rebuild.get("GOAMD64") == "v3")
        check("Rebuild turns on LTO and its error checks",
              "-flto" in rebuild["CFLAGS"] and "-Werror=odr" in rebuild["CFLAGS"])
        check("Rebuild keeps -march=native", "-march=native" in rebuild["CFLAGS"])
        check("Rebuild turns on lto and pgo", {"lto", "pgo"} <= set(rebuild["USE"].split()))
        check("Base uses ready-built packages", "getbinpkg" in base["FEATURES"].split())
        check("Rebuild stops using ready-built packages",
              rebuild["FEATURES"].split() == ["-getbinpkg"])
        compile_and_run(tmp, rebuild, "Rebuild")

        native, raptor = enabled("native"), enabled("raptorlake")
        print("Only with -march=native:", " ".join(sorted(native - raptor)))
        print("Only with -march=raptorlake:", " ".join(sorted(raptor - native)))
        check("-march=native adds what the chip has and raptorlake leaves out",
              {"-mabm", "-mshstk"} <= native - raptor)
        check("-march=native leaves out what the chip does not report",
              not {"-mkl", "-mwidekl", "-msgx"} & native)

        repo = open(os.path.join(CONFIG, "binrepos.conf", "gentoo.conf")).read()
        check("Binary repo is v3, with signatures checked",
              "/23.0/x86-64-v3/" in repo and "verify-signature = true" in repo)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("Result: %s" % ("all passed" if not fails else "%d failed" % fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
