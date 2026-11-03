#!/usr/bin/python3
"""Kiln Linux: past snapshots in the boot menu, and the restore command.

Commands:
  menu                Keeps the boot menu up to date. Run by systemd.
  restore             Lists the snapshots that can be restored, and asks which.
  restore NUMBER      Makes that snapshot the system from the next restart.
  restore --back      Goes back to the system set aside by the last restore.

A snapshot is offered only if it holds the disk guard and the kernel's drivers,
because a boot without the guard would leave every disk unlocked. Restore never
deletes the current system. It is set aside on the Crucial, for restore --back.
"""
import datetime
import fcntl
import fnmatch
import glob
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import kiln_guard

SNAPSHOTS = "/.snapshots"
ENTRIES = "/boot/loader/entries"
CMDLINE = "/proc/cmdline"
LOG = "/var/log/kiln/changes.log"
TOP = "/run/kiln-restore"
KEEP = 5
MILESTONES = 3
PREFIX = "kiln-snapshot-"
GUARD_FILES = ("usr/local/lib/kiln-guard/kiln_guard.py",
               "etc/systemd/system/local-fs-pre.target.wants/kiln-guard.service")
HOOK_FILE = "usr/local/lib/kiln-guard/kiln_rules.py"
ESSENTIAL_KERNELS = ("mlrig", "dist-bin")
LOADER = "/boot/loader/loader.conf"
SAFE_DEFAULT = "*-mlrig*"


class RestoreError(Exception):
    """Restore stopped, and the system was left as it was."""


# ---------------------------------------------------------------- reading

def booted_from_snapshot():
    with open(CMDLINE) as f:
        return "@snapshots/" in f.read()


def read_entry(path):
    entry = {"initrd": []}
    with open(path) as f:
        for line in f:
            key, _, value = line.strip().partition(" ")
            if key == "initrd":
                entry["initrd"].append(value.strip())
            elif key in ("version", "options", "linux"):
                entry[key] = value.strip()
    return entry


def kernel_entries():
    """Every kernel in the boot menu. Snapshot entries are not kernels."""
    return [read_entry(p) for p in sorted(glob.glob(os.path.join(ENTRIES, "*.conf")))
            if not os.path.basename(p).startswith(PREFIX)]


def read_kernels():
    """The mlrig kernels, which is what a snapshot boots with."""
    return [k for k in kernel_entries()
            if "mlrig" in k.get("version", "") and "linux" in k and re.search(
                r"rootflags=subvol=@(?:\s|$)", k.get("options", ""))]


def read_snapshots():
    """Snapshots that can be chosen, newest first. An after snapshot is left out."""
    found = []
    for name in os.listdir(SNAPSHOTS):
        if not name.isdigit():
            continue
        try:
            info = ET.parse(os.path.join(SNAPSHOTS, name, "info.xml")).getroot()
        except (OSError, ET.ParseError):
            continue  # Still being made, or damaged.
        if info.findtext("type") not in ("single", "pre"):
            continue
        root = os.path.join(SNAPSHOTS, name, "snapshot")
        if all(os.path.lexists(os.path.join(root, f)) for f in GUARD_FILES):
            milestone = any(u.findtext("key") == "milestone" and u.findtext("value") == "yes"
                            for u in info.findall("userdata"))
            found.append({"number": int(name), "root": root, "milestone": milestone,
                          "date": info.findtext("date") or "",
                          "description": info.findtext("description") or ""})
    return sorted(found, key=lambda s: s["number"], reverse=True)


def has_modules(snap, kernel):
    return os.path.isdir(os.path.join(snap["root"], "usr/lib/modules", kernel["version"]))


def pick(snapshots):
    """The newest snapshots, plus the newest milestones. Newest first."""
    newest = snapshots[:KEEP]
    marked = [s for s in snapshots if s["milestone"]][:MILESTONES]
    chosen = {s["number"]: s for s in newest + marked}
    return [chosen[n] for n in sorted(chosen, reverse=True)]


def title(snap):
    try:
        when = datetime.datetime.strptime(snap["date"], "%Y-%m-%d %H:%M:%S").replace(
            tzinfo=datetime.timezone.utc).astimezone().strftime("%-d %b %H:%M, ")
    except ValueError:
        when = ""
    words = " ".join(snap["description"].split())[:60]
    mark = "Milestone " if snap["milestone"] else "Snapshot "
    return "%s%d, %s%s" % (mark, snap["number"], when, words)


# ---------------------------------------------------------------- the boot menu

def render(snap, kernel):
    options = re.sub(r"rootflags=subvol=@(?=\s|$)",
                     "rootflags=subvol=@snapshots/%d/snapshot" % snap["number"],
                     kernel["options"])
    options = re.sub(r"(^|\s)rw(?=\s|$)", r"\1ro", options)
    lines = ["title      %s (read-only)" % title(snap),
             "version    %05d" % snap["number"],
             "sort-key   kiln-snapshot",
             "options    " + options,
             "linux      " + kernel["linux"]]
    lines += ["initrd     " + i for i in kernel["initrd"]]
    return "\n".join(lines) + "\n"


def wanted_entries(snapshots, kernels):
    usable, kernel_for = [], {}
    for snap in snapshots:
        for kernel in kernels:
            if has_modules(snap, kernel):
                usable.append(snap)
                kernel_for[snap["number"]] = kernel
                break
    return {"%s%05d.conf" % (PREFIX, s["number"]): render(s, kernel_for[s["number"]])
            for s in pick(usable)}


def update(wanted):
    """Writes only what changed, and removes only this program's own entries."""
    for name, text in wanted.items():
        path = os.path.join(ENTRIES, name)
        try:
            with open(path) as f:
                if f.read() == text:
                    continue
        except OSError:
            pass
        with open(path + ".tmp", "w") as f:
            f.write(text)
        os.replace(path + ".tmp", path)
    for path in glob.glob(os.path.join(ENTRIES, PREFIX + "*.conf")):
        if os.path.basename(path) not in wanted:
            os.unlink(path)


def cmd_menu():
    if booted_from_snapshot():
        return 0  # Leave the menu alone while running from a past snapshot.
    kernels = read_kernels()
    if not kernels:
        print("No mlrig kernel entry was found, so the menu was left alone.", file=sys.stderr)
        return 1
    update(wanted_entries(read_snapshots(), kernels))
    return 0


# ---------------------------------------------------------------- restore

def run(*command):
    done = subprocess.run(command, capture_output=True, text=True, timeout=300, check=False)
    if done.returncode != 0:
        raise RestoreError("%s failed: %s" % (command[0], done.stderr.strip()))
    return done.stdout.strip()


def crucial_partition():
    """The partition that holds the snapshots, proved to be on the Crucial by serial."""
    source = run("findmnt", "--noheadings", "--output", "SOURCE", "--target", SNAPSHOTS)
    device = re.sub(r"\[.*\]$", "", source)
    disks = kiln_guard.Disks()
    if not disks.on_target(os.path.basename(device), disks.target()):
        raise RestoreError("The snapshots are not on the Crucial, so nothing was done.")
    return device


def essential(kernel):
    """The default and rescue kernels. Others are experiments, named so as not to match."""
    return any(word in kernel.get("version", "") for word in ESSENTIAL_KERNELS)


def restorable():
    """Snapshots that can boot both the default and the rescue kernel."""
    kernels = [k for k in kernel_entries() if essential(k)]
    if not kernels:
        raise RestoreError("No default or rescue kernel was found, so nothing was done.")
    return [s for s in read_snapshots() if all(has_modules(s, k) for k in kernels)]


def kernels_lost_by(snap):
    """Boot menu kernels whose drivers are not in this snapshot, so they would not work."""
    return [k["version"] for k in kernel_entries()
            if "version" in k and not has_modules(snap, k)]


def make_default_safe(lost):
    """If the boot menu's default is a lost kernel, go back to mlrig. Returns True if so."""
    with open(LOADER) as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        key, _, value = line.strip().partition(" ")
        if key == "default" and any(
                fnmatch.fnmatch("id-%s.conf" % v, value.strip()) for v in lost):
            lines[i] = "default %s\n" % SAFE_DEFAULT
            with open(LOADER + ".tmp", "w") as f:
                f.writelines(lines)
            os.replace(LOADER + ".tmp", LOADER)
            return True
    return False


def old_systems(top):
    return sorted(os.path.basename(p) for p in glob.glob(os.path.join(top, "@.old-*")))


def swap(top, incoming):
    """Sets the current system aside and puts another in its place. Returns its new name."""
    stamp = "@.old-" + time.strftime("%Y%m%d-%H%M%S")
    aside, count = stamp, 0
    while os.path.lexists(os.path.join(top, aside)):
        count += 1
        aside = "%s-%d" % (stamp, count)
    os.rename(os.path.join(top, "@"), os.path.join(top, aside))
    try:
        os.rename(os.path.join(top, incoming), os.path.join(top, "@"))
    except OSError:
        os.rename(os.path.join(top, aside), os.path.join(top, "@"))
        raise
    return aside


def do_restore(top, number):
    incoming = "@.restore-%d" % number
    run("btrfs", "subvolume", "snapshot",
        os.path.join(top, "@snapshots", str(number), "snapshot"), os.path.join(top, incoming))
    try:
        return swap(top, incoming)
    except OSError as why:
        raise RestoreError("Nothing was changed. The new copy is left as %s. %s"
                           % (incoming, why)) from why


def do_back(top):
    systems = old_systems(top)
    if not systems:
        raise RestoreError("There is no system set aside to go back to.")
    try:
        return systems[-1], swap(top, systems[-1])
    except OSError as why:
        raise RestoreError("Nothing was changed. %s" % why) from why


def log_restore(words):
    with open(LOG, "a") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write("%s  #0 RESTORED %s\n" % (time.strftime("%Y-%m-%d %H:%M"), words))


def on_top_level(action):
    """Runs an action with the whole Crucial filesystem mounted, then unmounts it."""
    device = crucial_partition()
    os.makedirs(TOP, exist_ok=True)
    run("mount", "-o", "subvolid=5", device, TOP)
    try:
        return action(TOP)
    finally:
        run("umount", TOP)


def confirmed():
    return input("Type the word restore to go ahead: ").strip() == "restore"


def cmd_restore(argv):
    if os.geteuid() != 0:
        print("restore must run as root. Use the restore command.")
        return 1
    if not sys.stdin.isatty():
        print("restore only runs in a terminal, because the owner confirms it by hand.")
        return 1

    if argv[:1] == ["--back"]:
        print("This goes back to the system set aside by the last restore.")
        if not confirmed():
            print("Nothing was changed.")
            return 0
        back_to, aside = on_top_level(do_back)
        log_restore("back to %s, and the system before it is kept as %s" % (back_to, aside))
        print("Done. Restart the machine now. The system before this is kept as %s." % aside)
        return 0

    usable = restorable()
    if not argv:
        print("Snapshots that can be restored, newest first:")
        for snap in pick(usable):
            print("  " + title(snap))
        answer = input("Which number? Press Enter to stop: ").strip()
        if not answer:
            print("Nothing was changed.")
            return 0
        argv = [answer]
    if not argv[0].isdigit():
        print("Give a snapshot number, or --back.")
        return 1
    number = int(argv[0])
    snap = next((s for s in usable if s["number"] == number), None)
    if snap is None:
        print("Snapshot %d cannot be restored. Nothing was changed." % number)
        return 1

    print("Restoring: " + title(snap))
    print("The system goes back to this point at the next restart. Your current system is")
    print("kept, and restore --back returns to it. Your home folder, logs and kernels in")
    print("/boot do not change.")
    older = not os.path.lexists(os.path.join(snap["root"], HOOK_FILE))
    if older:
        print("This snapshot is older than the safety hooks. After the restart, run:")
        print("  cd ~/Projects/kiln && sudo sidekick/install.sh")
    lost = kernels_lost_by(snap)
    if lost:
        print("These kernels stay in the boot menu but will not work, as this snapshot is")
        print("older than they are. Do not choose them: " + ", ".join(lost))
    if not confirmed():
        print("Nothing was changed.")
        return 0
    aside = on_top_level(lambda top: do_restore(top, number))
    log_restore("to snapshot %d, and the system before it is kept as %s" % (number, aside))
    if make_default_safe(lost):
        print("The default kernel would not work from this snapshot, so the default is now mlrig.")
    print("Done. Restart the machine now. The system before this is kept as %s." % aside)
    return 0


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command == "menu":
        return cmd_menu()
    if command == "restore":
        try:
            return cmd_restore(argv[2:])
        except (RestoreError, OSError, subprocess.SubprocessError) as why:
            print("restore failed: %s" % why)
            return 1
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
