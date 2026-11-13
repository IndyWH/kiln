#!/usr/bin/python3
"""Kiln v2 safety rules, as Claude Code hooks, and the undo command.

Commands:
  pre      PreToolUse hook. A change is snapshotted and logged, then runs without asking.
  post     PostToolUse hook. Takes the after snapshot, checks the rescue entry.
  session  SessionStart hook. Tells Claude what changed since the last session.
  undo     Rolls back the last change. Run as root, through /usr/local/bin/undo.

Act, then inform (docs/PHILOSOPHY.md). Only outward actions, such as git push, ask.
Hard limits block silently: the rescue pieces and the owner's personal files.

This reads command text, so it can misjudge. Anything it does not recognise counts
as a change, which only means one more snapshot. The disk guard runs beside it and
does not depend on it.
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from kiln_guard import CannotParse, base, strip_wrappers, substitutions, tokenize

LOG_DIR = "/var/log/kiln"
LOG = LOG_DIR + "/changes.log"
PENDING = LOG_DIR + "/pending"
LAST_SESSION = LOG_DIR + "/last-session"
PACMAN_LOG = "/var/log/pacman.log"
GUARD_FILE = "/usr/local/lib/kiln-guard/kiln_guard.py"
OWNER_HOME = "/home/indy"

READ, CHANGE, OUTWARD = "read", "change", "outward"

# Programs that only read, whatever their arguments.
READ_PROGRAMS = {
    "ls", "stat", "file", "readlink", "realpath", "lsblk", "blkid", "findmnt", "cat",
    "head", "tail", "grep", "egrep", "fgrep", "rg", "od", "hexdump", "cmp", "diff",
    "sha1sum", "sha256sum", "sha512sum", "md5sum", "b2sum", "wc", "echo", "printf",
    "test", "[", "[[", "true", "false", "df", "du", "dirname", "basename", "sleep",
    "lspci", "lsusb", "lscpu", "lsmod", "free", "uptime", "who", "whoami", "id",
    "which", "type", "uniq", "cut", "tr", "paste", "strings", "nproc", "sensors",
    "ps", "pgrep", "ping", "getent", "uname", "cd", "pwd", "for", "export", "read",
    "wait", "seq", "column", "rev", "tac", "nl", "set", "nvidia-smi", "checkupdates",
    "pacman-conf", "limine-snapper-list", "inxi", "fastfetch", "visudo",
}
# Programs that only read, unless given one of these arguments.
READ_UNLESS = {
    "journalctl": ("--vacuum", "--rotate", "--flush", "--relinquish", "--sync", "--setup-keys"),
    "date": ("-s", "--set"),
    "ss": ("-K", "--kill"),
}
SAFE_PROGRAM_DIRS = ("/usr/bin/", "/usr/sbin/", "/bin/", "/sbin/", "/usr/local/bin/")
# Program -> the first arguments that only read.
READ_SUBCOMMANDS = {
    "systemctl": {"status", "is-active", "is-enabled", "is-failed", "is-system-running",
                  "list-units", "list-unit-files", "list-timers", "show", "cat", "--failed"},
    "hyprctl": {"version", "monitors", "clients", "workspaces", "activewindow",
                "activeworkspace", "binds", "devices", "layers", "systeminfo",
                "configerrors", "getoption", "cursorpos", "animations"},
    "wpctl": {"status", "get-volume", "inspect"},
    "pactl": {"list", "info", "stat"},
    "snapper": {"list", "status", "diff", "get-config", "list-configs"},
    "networkctl": {"list", "status"},
    "resolvectl": {"status", "query"},
    "localectl": {"status"},
    "timedatectl": {"status"},
}
# Git work that stays inside the repo, or only reads.
GIT_FREE = {"status", "log", "show", "diff", "add", "commit", "rev-list", "rev-parse",
            "ls-files", "ls-remote", "blame", "grep", "fetch", "check-ignore", "describe",
            "merge-base", "cat-file", "for-each-ref", "shortlog"}
PACKAGE_TOOLS = ("pacman", "paru", "yay")

# The rescue pieces (rule 2 of docs/PHILOSOPHY.md): the LTS kernel in the boot menu,
# the boot loader, and the snapshots with their boot menu entries.
RESCUE_PACKAGES = ("linux-cachyos-lts", "linux-cachyos-lts-nvidia-open", "limine",
                   "limine-snapper-sync", "limine-mkinitcpio-hook", "snapper", "snap-pac",
                   "btrfs-progs")
RESCUE_UNITS = ("limine-snapper-sync", "limine-snapper-watcher", "snapper-cleanup")
RESCUE_KERNEL = "/boot/vmlinuz-linux-cachyos-lts"
BOOT_MENU = "/boot/limine.conf"
REMOVERS = {"rm", "shred", "unlink", "rmdir", "trash", "trash-put", "gio"}


class Refused(Exception):
    """This must not run. The message is shown to Claude."""


# ---------------------------------------------------------------- what is a change

def free_paths():
    home = os.path.expanduser("~")
    return (home + "/Projects/kiln/", home + "/.claude/projects/",
            "/tmp/claude-%d/" % os.getuid())


def resolve(path, cwd):
    return os.path.realpath(path if os.path.isabs(path)
                            else os.path.join(cwd or ".", path))


def is_free(path, cwd):
    """True for the repo and Claude's own scratch space. Those are not the system."""
    full = resolve(path, cwd)
    return "/.git/" not in full + "/" and (full + "/").startswith(free_paths())


def git_kind(args):
    words = list(args)
    while words and words[0] == "-C":
        del words[:2]
    if not words or words[0].startswith("-"):
        return CHANGE
    sub, rest = words[0], words[1:]
    if any(a.startswith("--output") or a == "-o" for a in rest):
        return CHANGE
    if sub == "push":
        return OUTWARD
    if sub in GIT_FREE:
        return READ
    if sub == "branch" and all(a in ("-a", "-r", "-v", "--list", "--show-current")
                               or a.startswith("--format") for a in rest):
        return READ
    if sub == "config" and any(a in ("--get", "--get-all", "--list", "-l",
                                     "--show-origin") for a in rest):
        return READ
    return CHANGE


def package_kind(args):
    """pacman -Q, -Ss, -Si and -F only read. -Fy refreshes a database, so it changes."""
    op = next((a for a in args if a.startswith("-") and not a.startswith("--")), "")
    long_ops = [a for a in args if a.startswith("--")]
    if any(a in ("--query", "--deptest") for a in long_ops):
        return READ
    if op.startswith("-Q") or op.startswith("-T"):
        return READ
    if op.startswith("-S") and re.fullmatch(r"-S[sigl]+", op):
        return READ
    if op.startswith("-F") and "y" not in op:
        return READ
    return CHANGE


def program_kind(name, args):
    if name == "git":
        return git_kind(args)
    if name.startswith("python") and args == [GUARD_FILE, "status"]:
        return READ
    if name in READ_PROGRAMS:
        return READ
    if name in PACKAGE_TOOLS:
        return package_kind(args)
    if name in READ_UNLESS:
        return CHANGE if any(a.startswith(READ_UNLESS[name]) for a in args) else READ
    if name == "hostname":
        return CHANGE if any(not a.startswith("-") for a in args) else READ
    if name == "sort":
        return CHANGE if any(a == "-o" or a.startswith("--output") for a in args) else READ
    if name == "sed":
        # -i edits in place. The script commands w and e write files and run programs.
        return CHANGE if any(a.startswith(("-i", "--in-place")) or
                             re.search(r"(?:^|[;/\d\s])[wWe]\s+\S", a) for a in args) else READ
    if name == "awk":
        return CHANGE if any("system" in a or ">" in a or "|" in a for a in args) else READ
    if name == "find":
        return CHANGE if any(a in ("-delete", "-exec", "-execdir", "-ok", "-okdir")
                             or a.startswith("-fprint") for a in args) else READ
    if name == "ip":
        return CHANGE if any(a in ("add", "del", "delete", "set", "flush", "change",
                                   "replace", "append") for a in args) else READ
    if name == "efibootmgr":
        return READ if all(a in ("-v", "--verbose") for a in args) else CHANGE
    if name == "btrfs":
        return READ if args[:2] in (["subvolume", "list"], ["subvolume", "show"],
                                    ["filesystem", "show"], ["filesystem", "df"],
                                    ["filesystem", "usage"]) else CHANGE
    if name in READ_SUBCOMMANDS:
        allowed = READ_SUBCOMMANDS[name]
        words = [a for a in args if not a.startswith("-") or a in allowed]
        # snapper -c root list: the -c takes a value.
        if name == "snapper" and args[:1] in (["-c"], ["--config"]):
            words = [a for a in args[2:] if not a.startswith("-")]
        # hyprctl -j monitors, and pactl list short sinks.
        return READ if words and words[0] in allowed else CHANGE
    return CHANGE


def text_kind(text, cwd, depth=0):
    if depth > 6:
        return CHANGE
    try:
        commands = tokenize(text)
    except CannotParse:
        return CHANGE
    moved = any(words[:1] == ["cd"] for words, _, _ in commands)
    kind = READ
    for words, redirects, _ in commands:
        for op, dest in redirects:
            if not op.startswith((">", "&>", "<>")) or dest in ("/dev/null", "&1", "&2",
                                                                "1", "2"):
                continue
            # The shell has not expanded ~ or a variable at this point.
            dest = os.path.expanduser(dest)
            if ("$" in dest or (moved and not os.path.isabs(dest))
                    or not is_free(dest, cwd)):
                return CHANGE
        for word in words:
            for inner in substitutions(word):
                if text_kind(inner, cwd, depth + 1) == CHANGE:
                    return CHANGE
        real = strip_wrappers(words)
        if not real:
            continue
        # A program called ls in some other folder could do anything.
        if "/" in real[0] and not real[0].startswith(SAFE_PROGRAM_DIRS):
            return CHANGE
        found = program_kind(base(real[0]), real[1:])
        if found == CHANGE:
            return CHANGE
        if found == OUTWARD:
            kind = OUTWARD
    return kind


# ---------------------------------------------------------------- hard limits

def each_command(text, depth=0):
    """Every simple command in the text, wrappers such as sudo removed, as word lists."""
    if depth > 6:
        return
    try:
        commands = tokenize(text)
    except CannotParse:
        return
    for words, _, _ in commands:
        for word in words:
            for inner in substitutions(word):
                yield from each_command(inner, depth + 1)
        real = strip_wrappers(words)
        if real:
            yield [base(real[0])] + real[1:]


def removes_packages(words):
    if words[0] not in PACKAGE_TOOLS:
        return False
    return any(re.fullmatch(r"-R\w*", a) or a == "--remove" for a in words[1:])


def check_rescue_command(text):
    """Rescue pieces stay: the LTS kernel, the boot loader, snapshots and their menu."""
    why = ("This could remove the rescue kernel, the boot menu or the snapshots, which "
           "must stay. If it is really needed, the owner runs it by hand.")
    for words in each_command(text):
        name, args = words[0], words[1:]
        if removes_packages(words) and any(
                re.sub(r"^[\w-]+/", "", a) in RESCUE_PACKAGES for a in args):
            raise Refused(why)
        if name == "systemctl" and any(a in ("disable", "mask", "stop") for a in args) \
                and any(u in a for a in args for u in RESCUE_UNITS):
            raise Refused(why)
        if name == "snapper" and any(a in ("delete", "rm", "remove", "delete-config")
                                     for a in args):
            raise Refused(why)
        if name in REMOVERS | {"btrfs", "mv"}:
            for a in args:
                path = os.path.normpath(a) if a.startswith("/") else ""
                if path == "/boot" or path.startswith(("/boot/", "/.snapshots")) \
                        or "/.snapshots" in a:
                    raise Refused(why)


def personal_target(path, cwd):
    """True if the path is in the owner's home, but not a hidden settings folder,
    ~/Projects, or Claude's own space. Those are covered by home snapshots.
    The owner allowed deleting anything inside ~/Projects on 13 Nov 2026."""
    full = resolve(path, cwd)
    if not (full + "/").startswith(OWNER_HOME + "/") or is_free(full, cwd):
        return False
    if full.startswith(OWNER_HOME + "/Projects/"):
        return False
    rest = full[len(OWNER_HOME):].strip("/")
    return rest == "" or not rest.startswith(".")


def check_personal_files(text, cwd):
    """Never delete the owner's personal files."""
    why = ("This could delete the owner's personal files, which is never allowed. "
           "If it is really needed, the owner does it by hand.")
    for words in each_command(text):
        name, args = words[0], words[1:]
        targets = []
        if name in REMOVERS:
            targets = [a for a in args if not a.startswith("-") and a not in ("trash", "rm")]
        elif name == "find" and any(a in ("-delete", "-exec", "-execdir") for a in args):
            targets = [a for a in args if not a.startswith("-")][:1] or ["."]
        elif name == "rsync" and any(a.startswith("--delete") for a in args):
            targets = [a for a in args if not a.startswith("-")][-1:]
        for t in targets:
            t = os.path.expanduser(t.replace("$HOME", OWNER_HOME).replace("${HOME}", OWNER_HOME))
            if "$" in t:
                raise Refused("Name the path to delete plainly, without a variable, "
                              "so the personal files rule can check it.")
            if personal_target(t, cwd):
                raise Refused(why)


# ---------------------------------------------------------------- judging

def judge(payload):
    """Returns (kind, plain English text, command to log)."""
    tool_input = payload.get("tool_input") or {}
    cwd = payload.get("cwd")
    command = tool_input.get("command")
    if isinstance(command, str):
        check_rescue_command(command)
        check_personal_files(command, cwd)
        kind = text_kind(command, cwd)
        if kind == READ:
            return READ, "", ""
        said = " ".join(str(tool_input.get("description") or "").split())
        if len(said) < 10:
            raise Refused("This changes the system, so say in plain English what it "
                          "does, in the command's description.")
        return kind, said, command
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not isinstance(path, str):
        return READ, "", ""
    full = resolve(path, cwd)
    if full.startswith(("/boot/", "/.snapshots/")):
        raise Refused("Files in /boot and /.snapshots are not edited by hand. The boot "
                      "menu is made by limine-snapper-sync and the kernel packages.")
    if is_free(full, cwd):
        return READ, "", ""
    said = last_words(payload.get("transcript_path")) or "Change the file %s" % full
    return CHANGE, said, "Change the file %s" % full


def last_words(transcript):
    """What Claude last said to the owner, as the explanation for a file edit."""
    try:
        with open(transcript, "rb") as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - 200_000))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except (OSError, TypeError):
        return ""
    for line in reversed(lines):
        try:
            entry = json.loads(line)
            parts = entry["message"]["content"] if entry.get("type") == "assistant" else []
            texts = [p["text"] for p in parts
                     if isinstance(p, dict) and p.get("type") == "text"]
        except (ValueError, KeyError, TypeError):
            continue
        if texts:
            return " ".join(texts[-1].split())[:300]
    return ""


# ---------------------------------------------------------------- snapshots and log

def snapper(config, *args):
    done = subprocess.run(["sudo", "-n", "snapper", "-c", config, *args],
                          capture_output=True, text=True, timeout=120, check=False)
    if done.returncode != 0:
        raise RuntimeError("snapper %s failed: %s" % (config, done.stderr.strip()))
    return done.stdout.strip()


def snapshot_before(said):
    text = "kiln: " + said[:80]
    return {c: snapper(c, "create", "--type", "pre", "--print-number",
                       "--cleanup-algorithm", "number", "--description", text)
            for c in ("root", "home")}


def snapshot_after(before):
    return {c: snapper(c, "create", "--type", "post", "--pre-number", str(n),
                       "--print-number", "--cleanup-algorithm", "number",
                       "--description", "after")
            for c, n in before.items()}


def numbers(snaps):
    return "[root %s home %s]" % (snaps["root"], snaps["home"])


def new_entry(word, said, command, snaps):
    """Adds the first lines for a change. Returns its number."""
    stamp = time.strftime("%Y-%m-%d %H:%M")
    with open(LOG, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        number = sum(bool(re.match(r"^\S+ \S+  #\d+ (?:CHANGE|OUTWARD|ASKED) ", line))
                     for line in f) + 1
        where = numbers(snaps) if snaps else "[no snapshot]"
        f.write("%s  #%d %s %s %s\n" % (stamp, number, word, where, said))
        f.write("    command: %s\n" % " ".join(command.split())[:300])
    return number


def add_line(number, word, snaps=None):
    with open(LOG, "a") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write("%s  #%d %s%s\n" % (time.strftime("%Y-%m-%d %H:%M"), number, word,
                                    " " + numbers(snaps) if snaps else ""))


def pending_file(payload):
    name = re.sub(r"[^A-Za-z0-9_-]", "_", str(payload.get("tool_use_id") or "unknown"))
    return os.path.join(PENDING, name + ".json")


BIG = re.compile(r"\b(?:pacman|paru|yay)\b[^;&|\n]*\s-S\w*u|linux-cachyos|nvidia|limine")


def notify(text):
    """A desktop notice for something big. Never stops the hook."""
    try:
        subprocess.run(["notify-send", "--app-name=Kiln", "Kiln", text],
                       capture_output=True, timeout=10, check=False)
    except (OSError, subprocess.SubprocessError):
        pass


# ---------------------------------------------------------------- hooks

def hook_pre(payload):
    kind, said, command = judge(payload)
    if kind == READ:
        return 0
    snaps = snapshot_before(said) if kind == CHANGE else None
    number = new_entry("CHANGE" if snaps else "OUTWARD", said, command, snaps)
    with open(pending_file(payload), "w") as f:
        json.dump({"number": number, "snaps": snaps, "said": said, "command": command}, f)
    if kind == OUTWARD:
        decision, note = "ask", "This cannot be undone, so the owner decides."
    else:
        decision, note = "allow", "Snapshot taken."
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": "Change #%d: %s. %s" % (number, said.rstrip("."), note),
    }}))
    return 0


def rescue_entry_present():
    """The LTS kernel is on disk and in the boot menu."""
    done = subprocess.run(["sudo", "-n", "cat", BOOT_MENU], capture_output=True,
                          text=True, timeout=20, check=False)
    kernel = subprocess.run(["sudo", "-n", "test", "-e", RESCUE_KERNEL],
                            capture_output=True, timeout=20, check=False)
    if done.returncode != 0:
        return False
    in_menu = any(line.strip() == "//linux-cachyos-lts" for line in done.stdout.splitlines())
    return in_menu and kernel.returncode == 0


def hook_post(payload):
    try:
        with open(pending_file(payload)) as f:
            record = json.load(f)
        os.unlink(pending_file(payload))
    except OSError:
        return 0  # Not a change this hook logged.
    snaps, number = record["snaps"], record["number"]
    failed = payload.get("hook_event_name") == "PostToolUseFailure"
    word = "FAILED" if failed else "DONE"
    if (payload.get("tool_input") or {}).get("run_in_background"):
        add_line(number, "BACKGROUND")  # Still running, so no after snapshot yet.
    elif snaps:
        add_line(number, word, snapshot_after(snaps))
    else:
        add_line(number, word)
    if BIG.search(record.get("command") or ""):
        notify("Change #%d %s: %s" % (number, "failed" if failed else "done",
                                       record.get("said", "")))
    if snaps and not rescue_entry_present():
        notify("The rescue kernel is missing from the boot menu.")
        print("The rescue LTS kernel is no longer in the boot menu. Tell the owner now, "
              "and put it back, or run undo.", file=sys.stderr)
        return 2
    return 0


def hook_session(payload):
    """Prints what changed since the last session. Claude reads it and tells the owner."""
    try:
        with open(LAST_SESSION) as f:
            since = f.read().strip()
    except OSError:
        since = ""
    now = time.strftime("%Y-%m-%d %H:%M")
    if (payload or {}).get("source") not in ("resume", "compact", "clear"):
        try:
            with open(LAST_SESSION, "w") as f:
                f.write(now + "\n")
        except OSError:
            pass
    changes, packages = [], []
    try:
        with open(LOG) as f:
            changes = [l.rstrip() for l in f
                       if re.match(r"^\S+ \S+  #", l) and l[:16] >= since[:16]]
    except OSError:
        pass
    try:
        with open(PACMAN_LOG) as f:
            for line in f:
                m = re.match(r"^\[(\S{16})\S*\] \[ALPM\] (installed|upgraded|removed) (.*)$",
                             line)
                if m and m[1].replace("T", " ") >= since[:16]:
                    packages.append("%s %s" % (m[2], m[3]))
    except OSError:
        pass
    lines = ["Kiln: since the last session (%s):" % (since or "first session"),
             "%d change log lines, %d package changes." % (len(changes), len(packages))]
    lines += changes[-20:]
    if packages:
        lines.append("Packages, last 15:")
        lines += packages[-15:]
    lines.append("Tell the owner briefly what changed, in plain words.")
    print("\n".join(lines))
    return 0


# ---------------------------------------------------------------- undo

BROWSERS = re.compile(r"^/home/[^/]+/\.config/(?:mozilla|chromium|google-chrome)(?:/|$)")
SETTINGS = re.compile(r"^/home/[^/]+/\.config/")


def read_changes(path=None):
    """Every change that took snapshots and has not been undone, oldest first."""
    entries = {}
    with open(path or LOG) as f:
        for line in f:
            m = re.match(r"^\S+ \S+  #(\d+) (ASKED|CHANGE|DONE|FAILED|BACKGROUND|UNDONE|"
                         r"EMPTY|RESTORED)(?: \[root (\d+) home (\d+)\])?(?: (.*))?$",
                         line.rstrip("\n"))
            if not m:
                continue
            number, word = int(m[1]), m[2]
            if word == "RESTORED":
                entries.clear()  # Earlier changes no longer match the system.
            elif word in ("ASKED", "CHANGE") and m[3]:
                entries[number] = {"number": number, "said": m[5] or "", "root": m[3],
                                   "home": m[4], "ran": False, "root2": "0", "home2": "0"}
            elif number not in entries:
                continue
            elif word in ("UNDONE", "EMPTY"):
                del entries[number]
            elif word not in ("ASKED", "CHANGE"):
                entries[number]["ran"] = True
                if m[3]:
                    entries[number].update(root2=m[3], home2=m[4])
    return [e for _, e in sorted(entries.items()) if e["ran"]]


def changed_settings(listing):
    """From snapper's status lines: files under ~/.config, leaving out browsers."""
    out = []
    for line in listing.splitlines():
        path = line.split(" ", 1)[-1]
        if SETTINGS.match(path) and not BROWSERS.match(path):
            out.append(path)
    return out


def root_snapper(config, *args):
    done = subprocess.run(["snapper", "-c", config, *args], capture_output=True,
                          text=True, timeout=1800, check=False)
    if done.returncode != 0:
        raise RuntimeError("snapper %s %s failed: %s" % (config, args[0], done.stderr.strip()))
    return done.stdout


def find_last(changes):
    """The newest change that really changed something. Others are marked EMPTY,
    because a command that only read can be mistaken for a change."""
    for entry in reversed(changes):
        system = root_snapper("root", "status",
                              "%s..%s" % (entry["root"], entry["root2"])).splitlines()
        settings = changed_settings(root_snapper(
            "home", "status", "%s..%s" % (entry["home"], entry["home2"])))
        if system or settings:
            return entry, system, settings
        add_line(entry["number"], "EMPTY")
    return None, [], []


def cmd_undo(argv):
    if os.geteuid() != 0:
        print("undo must run as root. Use the undo command.")
        return 1
    try:
        changes = read_changes()
    except OSError:
        changes = []
    last, system, settings = find_last(changes)
    if last is None:
        print("There is no change to undo.")
        return 0
    root_range = "%s..%s" % (last["root"], last["root2"])
    home_range = "%s..%s" % (last["home"], last["home2"])

    print("Change #%d: %s" % (last["number"], last["said"]))
    print("This restores %d system files and %d settings files." % (len(system), len(settings)))
    print("Your other files, and the kernels in /boot, are not touched.")
    if last["root2"] == "0":
        print("This change ran in the background, so everything since it started goes back.")
    if "--yes" not in argv:
        if not sys.stdin.isatty():
            print("Nothing was changed. Run undo in a terminal, or add --yes.")
            return 1
        if input("Go ahead? (y/n) ").strip().lower() != "y":
            print("Nothing was changed.")
            return 0

    for config in ("root", "home"):
        root_snapper(config, "create", "--cleanup-algorithm", "number",
                     "--description", "before undo of change #%d" % last["number"])
    root_snapper("root", "undochange", root_range)
    if settings:
        root_snapper("home", "undochange", home_range, *settings)
    add_line(last["number"], "UNDONE")
    print("Done. Change #%d is undone. If the desktop still looks wrong, log out and in "
          "again, or restart the machine." % last["number"])
    return 0


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command == "undo":
        try:
            return cmd_undo(argv[2:])
        except (RuntimeError, OSError, subprocess.SubprocessError) as why:
            print("undo failed: %s" % why)
            return 1
    if command == "session":
        try:
            raw = sys.stdin.read() if not sys.stdin.isatty() else ""
            return hook_session(json.loads(raw) if raw.strip() else {})
        except BaseException:  # A summary must never stop a session starting.
            return 0
    if command not in ("pre", "post"):
        print(__doc__)
        return 64
    try:
        payload = json.load(sys.stdin)
        return hook_pre(payload) if command == "pre" else hook_post(payload)
    except Refused as why:
        print("Kiln rules: blocked. %s" % why, file=sys.stderr)
        return 2
    except BaseException as why:  # A change must not run without its snapshot.
        if command == "post":
            print("Kiln rules: the after step hit an error: %r" % why, file=sys.stderr)
            return 1
        print("Kiln rules: blocked, because the rules hook hit an error: %r" % why,
              file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
