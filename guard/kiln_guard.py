#!/usr/bin/python3
"""Kiln disk guard. Only the Crucial P2, found by serial, may be written to.

Commands:
  status         Show every disk and whether it is locked. Read-only.
  lock           Lock every disk except the Crucial (kernel read-only flag).
  lock-one NAME  Lock one device. Used by the fake-disk tests.
  udev NAME      Called by the udev rule when a disk appears.
  hook           Claude Code PreToolUse hook. Reads JSON, exit 2 means blocked.

The kernel lock is the real wall. The hook reads command text, so it catches
mistakes but cannot catch everything. Any doubt means locked, or blocked.
"""
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys

TARGET_SERIAL = "2128E5B7DBBC"
TARGET_MODEL = "CT1000P2SSD8"
BY_ID = "/dev/disk/by-id/"
VIRTUAL = ("loop", "ram", "zram")  # Not physical disks. Never swept.
NAME_OK = re.compile(r"^[A-Za-z0-9._-]+$")


# ---------------------------------------------------------------- disks

class Disks:
    """What the kernel says about the disks. Roots can point at a test folder."""

    def __init__(self, sysroot="/", devroot="/"):
        self.block = os.path.join(sysroot, "sys/block")
        self.devroot = devroot

    @staticmethod
    def _read(path):
        try:
            with open(path) as f:
                return f.read().strip()  # NVMe serials carry trailing spaces.
        except OSError:
            return ""

    def names(self):
        return sorted(os.listdir(self.block))

    def serial(self, name):
        return self._read(os.path.join(self.block, name, "device/serial"))

    def model(self, name):
        return self._read(os.path.join(self.block, name, "device/model"))

    def partitions(self, name):
        base = os.path.join(self.block, name)
        return sorted(p for p in os.listdir(base)
                      if os.path.exists(os.path.join(base, p, "partition")))

    def parent(self, name):
        """The whole disk a device belongs to, or None if unknown."""
        for disk in self.names():
            if name == disk or name in self.partitions(disk):
                return disk
        return None

    def ro(self, name):
        parent = self.parent(name)
        if parent is None:
            return None
        sub = name if parent == name else os.path.join(parent, name)
        return self._read(os.path.join(self.block, sub, "ro")) == "1"

    def target(self):
        """The one Crucial, by serial. None unless exactly one matches."""
        hits = [n for n in self.names() if self.serial(n) == TARGET_SERIAL]
        if len(hits) == 1 and self.model(hits[0]) == TARGET_MODEL:
            return hits[0]
        return None

    def on_target(self, name, target, depth=0):
        """True if this device lives only on the Crucial. Follows dm and md."""
        if target is None or depth > 8:
            return False
        parent = self.parent(name)
        if parent is None:
            return False
        if parent == target:
            return True
        try:
            slaves = os.listdir(os.path.join(self.block, parent, "slaves"))
        except OSError:
            return False
        return bool(slaves) and all(
            self.on_target(s, target, depth + 1) for s in slaves)

    def lock_list(self):
        """Every device that must be locked. All of them if no Crucial is found."""
        target = self.target()
        out = []
        for disk in self.names():
            if disk.startswith(VIRTUAL) or self.on_target(disk, target):
                continue
            out.append(disk)
            out.extend(self.partitions(disk))
        return out

    def resolves_to_target(self, path):
        real = os.path.realpath(self.devroot.rstrip("/") + path)
        return self.on_target(os.path.basename(real), self.target())


def mask(serial):
    """Other disks' serials stay out of the public repo: last 4 only."""
    if serial == TARGET_SERIAL or not serial:
        return serial or "-"
    return "****" + serial[-4:]


def blockdev_path():
    found = shutil.which("blockdev") or shutil.which(
        "blockdev", path="/usr/bin:/usr/sbin:/bin:/sbin")
    if not found:
        raise RuntimeError("blockdev not found")
    return found


def lock_device(disks, name):
    """Set the kernel read-only flag. blockdev opens the device read-only."""
    if not NAME_OK.match(name):
        raise ValueError("bad device name: %r" % name)
    if disks.ro(name):
        return True  # Also stops the change event this causes from looping.
    subprocess.run([blockdev_path(), "--setro", "/dev/" + name],
                   check=False, capture_output=True, timeout=20)
    return disks.ro(name) is True


def cmd_lock():
    disks = Disks()
    target = disks.target()
    failed = [n for n in disks.lock_list() if not lock_device(disks, n)]
    for name in failed:
        print("FAILED TO LOCK: %s" % name)
    if target is None:
        print("CRUCIAL NOT FOUND BY SERIAL: every disk was locked.")
    return 1 if failed or target is None else 0


def cmd_lock_one(name):
    disks = Disks()
    if disks.on_target(name, disks.target()):
        print("Refused: %s is the Crucial." % name)
        return 1
    return 0 if lock_device(disks, name) else 1


def cmd_udev(name):
    disks = Disks()
    if name.startswith(VIRTUAL) or disks.on_target(name, disks.target()):
        return 0
    return 0 if lock_device(disks, name) else 1


def cmd_status():
    disks = Disks()
    target = disks.target()
    must_lock = set(disks.lock_list())
    bad = 0
    print("%-14s %-14s %-22s %s" % ("DEVICE", "SERIAL", "MODEL", "STATE"))
    for disk in disks.names():
        if disk.startswith(VIRTUAL):
            continue
        for name in [disk] + disks.partitions(disk):
            if name not in must_lock:
                state = "writable (the Crucial)"
            elif disks.ro(name):
                state = "locked"
            else:
                state = "NOT LOCKED"
                bad += 1
            print("%-14s %-14s %-22s %s" % (
                name,
                mask(disks.serial(disk)) if name == disk else "",
                disks.model(disk)[:22] if name == disk else "",
                state))
    if target is None:
        print("CRUCIAL NOT FOUND BY SERIAL.")
    print("Result: %s" % ("OK" if not bad and target else "NOT SAFE"))
    return 0 if not bad and target else 1


# ---------------------------------------------------------------- hook rules

class Blocked(Exception):
    """The command must not run. The message is shown to Claude."""


class CannotParse(Exception):
    pass


MENTION = re.compile(r"(?<![\w.\-/~])/dev(?:/[^\s'\"`;|&<>(),:=]*)?(?![\w.\-])")
# A device reached through another path, such as /mnt/gentoo/dev/sda.
NESTED = re.compile(r"[\w.\-/~}]/dev/(?:sd[a-z]|hd[a-z]|vd[a-z]|nvme\d|ng\d|sg\d"
                    r"|mmcblk\d|dm-\d|md\d|mapper/|disk/)")
SYS_DISK = re.compile(r"/sys/(?:block|class/block|class/nvme|class/scsi_disk"
                      r"|class/scsi_device|bus/scsi)\b")
SAFE_DEV = re.compile(
    r"^/dev/(?:null|zero|full|random|urandom|tty\d*|ptmx|pts(?:/\S*)?|stdin"
    r"|stdout|stderr|fd(?:/\S*)?|shm(?:/\S*)?|console|kmsg|rtc\d*|loop-control"
    r"|loop\d+(?:p\d+)?|dri(?:/\S*)?|snd(?:/\S*)?|input(?:/\S*)?|net/tun|kvm"
    r"|mqueue(?:/\S*)?|hugepages(?:/\S*)?|cpu(?:/\S*)?|nvidia\S*)$")
ANSI_QUOTE = re.compile(r"\$'[^']*\\")

PROTECTED = ("/etc/claude-code", "managed-settings", "/usr/local/lib/kiln-guard",
             "99-kiln-guard", "/etc/udev/rules.d", "guard/install.sh")
TAMPER = ("--setrw", "BLKROSET", "0x125d", "disableAllHooks")
INSTALLED_GUARD = "/usr/local/lib/kiln-guard/kiln_guard.py"

DANGEROUS = {
    "dd", "mkfs", "mke2fs", "mkswap", "wipefs", "sgdisk", "gdisk", "sfdisk",
    "fdisk", "cfdisk", "cgdisk", "parted", "partprobe", "blkdiscard", "shred",
    "badblocks", "nvme", "hdparm", "sdparm", "fsck", "e2fsck", "tune2fs",
    "resize2fs", "cryptsetup", "pvcreate", "vgcreate", "lvcreate", "mdadm",
    "zpool", "swapon", "blockdev", "fstrim",
}
DANGEROUS_PREFIX = ("mkfs.", "fsck.", "sg_", "xfs_")
SHELLS = {"sh", "bash", "dash", "zsh", "ksh", "ash", "fish", "su"}
INTERPRETERS = re.compile(r"^(?:python[\d.]*|perl|ruby|node|lua|php|tclsh)$")
# Programs that take a path or text as data and do not write to their arguments.
PLAIN_READ = {
    "ls", "stat", "file", "readlink", "realpath", "lsblk", "blkid", "findmnt",
    "cat", "head", "tail", "grep", "egrep", "fgrep", "od", "hexdump", "cmp",
    "sha1sum", "sha256sum", "sha512sum", "md5sum", "b2sum", "wc", "echo",
    "printf", "test", "[", "true", "false", "df", "du", "dirname", "basename",
    "sleep", "dumpe2fs", "lspci", "lsusb",
}
TEXT_ARGS = {"git", "emerge"}  # Their arguments are never device targets.
KEYWORDS = {"if", "then", "elif", "else", "fi", "do", "done", "while", "until",
            "{", "}", "!", "time", "case", "esac"}
# Wrapper name -> (options that take a value, leading positional arguments).
WRAPPERS = {
    "sudo": ("-u -g -h -p -C -T -r -t -U -D -R", 0), "doas": ("-u -C", 0),
    "env": ("-u -C -S", 0), "nice": ("-n", 0), "ionice": ("-c -n -p", 0),
    "nohup": ("", 0), "timeout": ("-s -k", 1), "stdbuf": ("-i -o -e", 0),
    "setsid": ("", 0), "chrt": ("", 1), "taskset": ("", 1), "exec": ("-a", 0),
    "command": ("", 0), "builtin": ("", 0), "chroot": ("", 1), "busybox": ("", 0),
    "unshare": ("", 0), "nsenter": ("-t", 0), "flock": ("", 1), "runuser": ("-u", 0),
}


def tokenize(text):
    """Split shell text into simple commands of (words, redirects, piped_in).

    Quotes are removed and pieces joined, as the shell does. Newlines, ; & | (
    and ) end a command, so subshells become separate commands too.
    """
    commands, words, redirects = [], [], []
    word, in_word, piped = "", False, False
    pending_redirect, i, n = None, 0, len(text)

    def end_word():
        nonlocal word, in_word, pending_redirect
        if in_word:
            if pending_redirect:
                redirects.append((pending_redirect, word))
                pending_redirect = None
            else:
                words.append(word)
        word, in_word = "", False

    def end_command(next_piped):
        nonlocal words, redirects, piped
        end_word()
        if words or redirects:
            commands.append((words, redirects, piped))
        words, redirects, piped = [], [], next_piped

    while i < n:
        c = text[i]
        if c == "#" and not in_word:  # A comment runs to the end of the line.
            end = text.find("\n", i)
            i = n if end < 0 else end
        elif c == "\\":
            if i + 1 >= n:
                raise CannotParse("trailing backslash")
            if text[i + 1] != "\n":
                word += text[i + 1]
                in_word = True
            i += 2
        elif c == "'":
            end = text.find("'", i + 1)
            if end < 0:
                raise CannotParse("open quote")
            word += text[i + 1:end]
            in_word = True
            i = end + 1
        elif c == '"':
            i += 1
            in_word = True
            while True:
                if i >= n:
                    raise CannotParse("open quote")
                if text[i] == "\\" and i + 1 < n:
                    if text[i + 1] != "\n":
                        word += text[i + 1]
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    word += text[i]
                    i += 1
        elif c in " \t":
            end_word()
            i += 1
        elif c == "&" and text[i:i + 2] == "&>":
            end_word()
            pending_redirect = "&>"
            i += 2
            if text[i:i + 1] == ">":
                i += 1
        elif c in "<>":
            if in_word and word.isdigit():
                word, in_word = "", False
            end_word()
            j = i + 1
            while j < n and text[j] in "<>|&":
                j += 1
            pending_redirect = text[i:j]
            i = j
        elif c in "\n;&|()`":
            # A single | feeds the next command. || and |& are treated alike.
            end_command(c == "|")
            i += 1
        else:
            word += c
            in_word = True
            i += 1
    end_command(False)
    return commands


def substitutions(word):
    """The text inside $(...) and backticks that sits inside a quoted word."""
    out, i = [], 0
    while True:
        i = word.find("$(", i)
        if i < 0:
            break
        depth, j = 1, i + 2
        while j < len(word) and depth:
            depth += {"(": 1, ")": -1}.get(word[j], 0)
            j += 1
        out.append(word[i + 2:j - 1 if not depth else j])
        i += 2
    out.extend(re.findall(r"`([^`]*)`", word))
    return out


def mentions(word):
    found = MENTION.findall(word)
    if NESTED.search(word):
        found.append(word)
    if SYS_DISK.search(word):
        found.append(word)
    # A glob that the shell would expand to /dev, such as /d?v/sda.
    if re.match(r"^/[^/]*[*?\[][^/]*(?:/|$)", word) and fnmatch.fnmatch(
            "dev", word.split("/")[1]):
        found.append(word)
    return found


def classify(path, disks):
    """safe, allowed (the Crucial, by serial) or other."""
    if path == "/dev":
        return "root"
    if SAFE_DEV.match(path) and ".." not in path:
        return "safe"
    if (path.startswith(BY_ID) and TARGET_SERIAL in path
            and not re.search(r"[$*?\[{`]|\.\.", path)
            and disks.resolves_to_target(path)):
        return "allowed"
    return "other"


def base(program):
    return program.rsplit("/", 1)[-1]


def is_dangerous(program):
    name = base(program)
    return name in DANGEROUS or name.startswith(DANGEROUS_PREFIX)


def strip_wrappers(words):
    """Drop assignments, keywords and wrappers like sudo. Returns the real command."""
    words = list(words)
    while words:
        first = words[0]
        if re.match(r"^[A-Za-z_]\w*=", first) or first in KEYWORDS:
            words.pop(0)
            continue
        name = base(first)
        if name not in WRAPPERS:
            break
        takes_value, positional = WRAPPERS[name]
        takes_value = takes_value.split()
        words.pop(0)
        while words:
            w = words[0]
            if w == "--":
                words.pop(0)
                break
            if w in takes_value:
                del words[:2]
            elif w.startswith("-") and len(w) > 1:
                words.pop(0)
            elif name == "env" and "=" in w:
                words.pop(0)
            else:
                break
        del words[:positional]
    return words


def read_only_form(name, args):
    """True if this exact use of the program only reads."""
    if name in PLAIN_READ:
        return True
    if name == "git":
        return not any(a == "-o" or a.startswith("--output") for a in args)
    if name == "blockdev":
        return all(a.startswith(("--get", "--report")) or not a.startswith("-")
                   for a in args) and any(a.startswith("-") for a in args)
    if name in ("fdisk", "gdisk"):
        return "-l" in args or "--list" in args
    if name == "sfdisk":
        return any(a in ("-l", "--list", "-d", "--dump", "-J", "--json") for a in args)
    if name == "sgdisk":
        return bool(args) and all(
            a in ("-p", "--print") or not a.startswith("-") for a in args
        ) and any(a in ("-p", "--print") for a in args)
    if name == "parted":
        if "-l" in args or "--list" in args:
            return True
        return [a for a in args if not a.startswith(("-", "/"))] == ["print"]
    if name == "udevadm":
        return args[:1] == ["info"]
    if name == "smartctl":
        return not any(
            a.startswith(("-t", "--test", "-s", "--smart", "-S", "--saveauto",
                          "-o", "--offlineauto", "-X", "--abort", "--set"))
            for a in args)
    if name == "nvme":
        return args[:1] in (["list"], ["id-ctrl"], ["id-ns"], ["smart-log"],
                            ["error-log"], ["fw-log"])
    if name == "hdparm":
        return args == ["-I"] or (args[:1] == ["-I"] and len(args) == 2)
    if name == "tune2fs":
        return args[:1] == ["-l"]
    if name == "cryptsetup":
        return args[:1] in (["luksDump"], ["status"])
    if name == "btrfs":
        return args[:2] == ["filesystem", "show"]
    return False


def read_text_file(path, cwd):
    """A short text file's contents, or None if it is missing, huge or binary."""
    full = path if os.path.isabs(path) else os.path.join(cwd or ".", path)
    try:
        if os.path.getsize(full) > 1_000_000:
            return None
        with open(full, "rb") as f:
            data = f.read()
    except OSError:
        return None
    return None if b"\0" in data else data.decode("utf-8", "replace")


def check_shell(name, args, disks, cwd, depth):
    """Look inside bash -c, su -c and script files."""
    for i, a in enumerate(args):
        if a == "-c" or (name != "su" and re.match(r"^-[a-zA-Z]*c[a-zA-Z]*$", a)):
            if i + 1 >= len(args):
                raise Blocked("A shell was given -c with nothing to read.")
            check_text(args[i + 1], disks, cwd, depth + 1)
            return
    scripts = [a for a in args if not a.startswith("-")]
    if name == "su" or not scripts:
        raise Blocked("A shell reading its commands from a pipe cannot be "
                      "checked. Write the commands out, or ask the owner to run it.")
    text = read_text_file(scripts[0], cwd)
    if text is None:
        raise Blocked("The script %s cannot be read, so it cannot be checked."
                      % scripts[0])
    check_text(text, disks, cwd, depth + 1)


def check_file_mentions(path, text, disks):
    for found in mentions(text):
        if classify(found, disks) not in ("safe", "allowed"):
            raise Blocked("%s names a disk device (%s)." % (path, found))


def check_simple(words, redirects, disks, cwd, depth):
    target = disks.target()

    for op, dest in redirects:
        if not op.startswith((">", "&>", "<>")):
            continue
        if any(p in dest for p in PROTECTED):
            raise Blocked("Writing to the guard's own files is not allowed.")
        for found in mentions(dest):
            if classify(found, disks) not in ("safe", "allowed"):
                raise Blocked("Writing to %s is not allowed. Only the Crucial "
                              "may be written to, named by its serial." % found)

    found = [m for w in words + [d for _, d in redirects] for m in mentions(w)]
    kinds = {m: classify(m, disks) for m in found}
    others = [m for m, k in kinds.items() if k == "other"]

    real = strip_wrappers(words)
    if not real:
        if others:
            raise Blocked("Saving a device path in a variable hides it from the "
                          "guard: %s." % others[0])
        return
    program, args = real[0], real[1:]
    name = base(program)

    if name in ("eval", "source", ".") or name in SHELLS:
        if name == "eval":
            check_text(" ".join(args), disks, cwd, depth + 1)
        elif name in SHELLS:
            check_shell(name, args, disks, cwd, depth)
        else:
            check_shell("sh", args, disks, cwd, depth)
        if others:
            raise Blocked("This names a disk device: %s." % others[0])
        return

    if name == "cd" or name == "pushd":
        if found and any(k != "safe" for k in kinds.values()):
            raise Blocked("Working from inside /dev hides device paths from the guard.")
        return

    joined = " ".join(real)
    if program == "/usr/bin/python3" or INTERPRETERS.match(name):
        if args[:1] == [INSTALLED_GUARD] and args[1:2] in (["status"], ["lock"]):
            return
    read_only = name in PLAIN_READ or read_only_form(name, args)
    if not read_only and any(p in joined for p in PROTECTED):
        raise Blocked("Changing the guard's own files is not allowed. "
                      "The owner does that by hand.")
    if not read_only and any(t in joined for t in TAMPER):
        raise Blocked("Turning the disk lock or the hooks off is not allowed.")
    if name == "udevadm" and args[:1] == ["control"]:
        raise Blocked("Changing how udev runs could switch the guard off.")

    if target is None and (found and any(k != "safe" for k in kinds.values())
                           or is_dangerous(name)):
        raise Blocked("The Crucial was not found by serial, so all disk commands "
                      "are blocked.")

    if name == "dd":
        out = [a[3:] for a in args if a.startswith("of=")]
        for dest in out:
            if re.search(r"[$`*?\[]", dest) or re.match(
                    r"^(?:sd[a-z]|nvme\d|hd[a-z]|vd[a-z]|mmcblk\d|dm-\d|md\d)", dest):
                raise Blocked("dd must write to a plain path, not %s." % dest)
            for m in mentions(dest):
                if classify(m, disks) not in ("safe", "allowed"):
                    raise Blocked("dd may only write to the Crucial, named by its "
                                  "serial under %s. Not %s." % (BY_ID, m))
        return

    if read_only:
        return

    if name in ("mount", "swapon"):
        if any(a in ("-a", "--all") or a.startswith(
                ("LABEL=", "UUID=", "PARTLABEL=", "PARTUUID=")) for a in args):
            raise Blocked("mount by label or -a could pick another disk. Name the "
                          "Crucial by serial under %s." % BY_ID)
        if others:
            raise Blocked("Only the Crucial may be mounted, named by its serial. "
                          "Not %s." % others[0])
        if name == "mount":
            return

    if others:
        raise Blocked("This names a device that is not the Crucial by serial: %s. "
                      "Use %s...%s." % (others[0], BY_ID, TARGET_SERIAL))
    if "root" in kinds.values():
        raise Blocked("Passing all of /dev to %s is not allowed." % name)

    dangerous = is_dangerous(name) or (
        name not in TEXT_ARGS and any(is_dangerous(w) for w in args))
    if dangerous:
        if any(re.search(r"[$`*?\[]", a) for a in args):
            raise Blocked("Disk tools must name the Crucial in full, with no "
                          "variables or wildcards.")
        if "allowed" not in kinds.values():
            raise Blocked("%s must name the Crucial by serial under %s."
                          % (name, BY_ID))
        return

    if INTERPRETERS.match(name):
        for a in args:
            text = read_text_file(a, cwd) if not a.startswith("-") else None
            if text is not None:
                check_file_mentions(a, text, disks)
        return

    # A script run directly, such as ./x.sh. System programs are not read.
    if "/" in program and not program.startswith(("/usr/", "/bin/", "/sbin/")):
        text = read_text_file(program, cwd)
        if text is None:
            if not os.path.exists(program if os.path.isabs(program)
                                  else os.path.join(cwd or ".", program)):
                raise Blocked("%s cannot be found, so it cannot be checked." % program)
            return  # A binary. The kernel lock is what covers this case.
        if text.startswith("#!") and "sh" not in text.split("\n", 1)[0]:
            check_file_mentions(program, text, disks)
        else:
            check_text(text, disks, cwd, depth + 1)


def check_text(text, disks, cwd, depth=0):
    if depth > 6:
        raise Blocked("Too many layers of shell to check.")
    if ANSI_QUOTE.search(text):
        raise Blocked("Escape codes in quotes can hide a device path.")
    try:
        commands = tokenize(text)
    except CannotParse:
        # Could not be read as shell. Judge the raw text instead.
        for found in mentions(text):
            if classify(found, disks) not in ("safe", "allowed"):
                raise Blocked("This could not be read, and it names %s." % found)
        if any(is_dangerous(w) for w in re.split(r"[^\w.+-]+", text)):
            raise Blocked("This could not be read, and it names a disk tool.")
        return
    for words, redirects, piped in commands:
        for w in words + [d for _, d in redirects]:
            for inner in substitutions(w):
                check_text(inner, disks, cwd, depth + 1)
        check_simple(words, redirects, disks, cwd, depth)


def check_path(path, cwd):
    """For the Write, Edit and NotebookEdit tools."""
    full = os.path.realpath(path if os.path.isabs(path)
                            else os.path.join(cwd or ".", path))
    if any(p in full for p in PROTECTED):
        raise Blocked("Changing the guard's own files is not allowed.")
    if full.startswith("/sys/") or (full.startswith("/dev/")
                                    and not SAFE_DEV.match(full)):
        raise Blocked("Writing to %s is not allowed." % full)


def decide(payload, disks):
    """Raises Blocked if the tool call must not run. Never runs the call."""
    tool_input = payload.get("tool_input") or {}
    cwd = payload.get("cwd")
    for key in ("file_path", "notebook_path"):
        if isinstance(tool_input.get(key), str):
            check_path(tool_input[key], cwd)
    command = tool_input.get("command")
    if isinstance(command, str):
        check_text(command, disks, cwd)


def cmd_hook():
    """Exit 2 is the only code that blocks, so every failure must end there."""
    try:
        decide(json.load(sys.stdin), Disks())
    except Blocked as why:
        print("Kiln disk guard: blocked. %s" % why, file=sys.stderr)
        return 2
    except BaseException as why:  # Any fault here must block, not let through.
        print("Kiln disk guard: blocked, because the guard hit an error: %r"
              % why, file=sys.stderr)
        return 2
    return 0


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command == "hook":
        return cmd_hook()
    if command == "status":
        return cmd_status()
    if command == "lock":
        return cmd_lock()
    if command == "lock-one" and len(argv) == 3:
        return cmd_lock_one(argv[2])
    if command == "udev" and len(argv) == 3:
        return cmd_udev(argv[2])
    print(__doc__)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
