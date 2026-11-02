# Hardware

Disks, the disk guard, and what the tools really do on this machine.

## Disks

- Find the Crucial by serial only. Use `/dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC`, and add `-part1` for a partition. On 2 Nov 2026 it was `nvme1n1`, but do not rely on that.
- NVMe serials in `/sys/block/*/device/serial` have trailing spaces. Trim them before comparing.
- The Ventoy USB drive reports a different serial through the USB bridge than through the drive itself. Treat its identity as unreliable.
- The Crucial's write count was 3 at the first look, on the live system. All 3 were empty cache flushes, with 0 sectors of data. So check sectors written, not only the write count.

## The live system

- It is OpenRC, while the installed system will be systemd. Do not assume systemd tools work here.
- The `gentoo` user has passwordless root and is in the `disk` group, so it can write to raw disks without sudo. Nothing on the image protects the disks by default.
- `udisksd` runs on the live desktop and can mount disks.
- Everything outside GitHub is lost on restart, including the guard. Run `guard/install.sh` again after each boot, before any disk work.

## The disk guard

- The kernel read-only flag is the real wall. It stops ordinary writes from any program, including root. `blockdev --setro` opens the device read-only, and nothing reaches the drive.
- The flag does not stop raw drive commands such as `nvme format` or `sg_raw`, and root can turn it off. Only the Claude Code hook covers those, and the hook reads command text, so it cannot catch everything.
- Claude Code hooks let the action through if the hook crashes or fails to start, unless the hook sets `onFailure: block`. In the script itself, only exit code 2 blocks.
- A disk that appears is locked by udev a moment later, so there is a very short gap.
- After `guard/install.sh`, restart Claude Code so it loads the hook. `/etc/claude-code` did not exist when the session began.
- Disk commands must name the Crucial in full under `/dev/disk/by-id/`, on one line, with no variables or wildcards. Otherwise the hook blocks them.
- The hook blocks Claude from running `tests/guard/fake_disks.sh`, because the script names raw devices. The owner runs it in a terminal. Do not try to get round this.

## Tool pitfalls

- `sgdisk --zap-all` on a locked disk prints `GPT data structures destroyed!` and exits 0, although the kernel refused every write. Never trust its exit code. Read the partition table back after any change.
- A write-mode open of a locked disk succeeds. The refusal comes at the write. So a successful open proves nothing.
- `dd of=/dev/x` makes a plain file if the device node has gone, and reports success. Use `conv=nocreat`.
- A loop device keeps its read-only flag after it is detached, so the next use of that loop device starts locked.
- Writing to the first sectors of a disk damages its partition table, and the kernel then removes the partitions. That is how the node above went missing during a test.
