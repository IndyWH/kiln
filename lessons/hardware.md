# Hardware

Disks, the disk guard, and what the tools really do on this machine.

Full report: `docs/HARDWARE.md`.

## Disks

- The Crucial's health on 2 Nov 2026: 2% of rated life used, 13.4 TB written, 8,977 hours, no media errors. Compare against this if it misbehaves.
- Find the Crucial by serial only. Use `/dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC`, and add `-part1` for a partition. On 2 Nov 2026 it was `nvme1n1`, but do not rely on that.
- NVMe serials in `/sys/block/*/device/serial` have trailing spaces. Trim them before comparing.
- The Ventoy USB drive reports a different serial through the USB bridge than through the drive itself. Treat its identity as unreliable.
- The Crucial's write count was 3 at the first look, on the live system. All 3 were empty cache flushes, with 0 sectors of data. So check sectors written, not only the write count.

- Layout: `docs/DISK_LAYOUT.md`. The old Omarchy firmware boot entries still exist and point at nothing.
- After partitioning, the guard's udev rule correctly left the Crucial's new partitions writable.

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
- The hook sometimes blocks harmless commands, because it reads text. Seen so far: `which nvme`, where the word counts as a disk tool, a `sed` pattern containing `/sys/block`, and Markdown backticks inside single quotes, which it reads as a command. Write text with the file tools instead. Use a simpler read-only command, such as `ls` or `grep`. If a command is blocked, re-check what it does before rewording it.

- The guard on Kiln goes on by the owner's hand, with `scripts/guard-to-kiln.sh`. It adds `kiln-guard.service`, which locks the disks early in each boot. The start-up image runs before that, with no locks.
- The hook refuses a script inside the chroot, such as `chroot /mnt/gentoo bash /usr/src/x.sh`, because it looks for that path outside the chroot and cannot read it. Run the commands one by one, so it can read each. For a script on the Crucial that can run from outside, use its `/mnt/gentoo` path.
- The hook also stops the `Read` tool opening files in `guard/`, with the message about changing them. `sha256sum` on them is allowed. Review this at step 10.

## Tool pitfalls

- `grep` on the live image is `ugrep`, which goes down into folders by itself. A wildcard path under `/sys` can match folders and produce a huge output. Name exact files.
- To work inside the new system, use `chroot`, so the hook can still read the commands. `arch-chroot` would hide them, because the hook does not know it.
- `/dev` is connected inside the chroot, so the kernel lock is what protects the other disks there.
- Hardware output can hide IDs. `pactl info` puts the webcam's serial in the default source name, and `kscreen-doctor` prints a unique screen ID. Filter by keeping known-safe lines, and run a search for IDs, before anything goes in the public repo.
- `sgdisk --zap-all` on a locked disk prints `GPT data structures destroyed!` and exits 0, although the kernel refused every write. Never trust its exit code. Read the partition table back after any change.
- A write-mode open of a locked disk succeeds. The refusal comes at the write. So a successful open proves nothing.
- `dd of=/dev/x` makes a plain file if the device node has gone, and reports success. Use `conv=nocreat`.
- A loop device keeps its read-only flag after it is detached, so the next use of that loop device starts locked.
- Writing to the first sectors of a disk damages its partition table, and the kernel then removes the partitions. That is how the node above went missing during a test.
- The hook looks for a program path before the command runs, outside the chroot. A path that only exists inside the chroot, or that an earlier part of the same command creates, is refused. Check such a program in a later command, by its `/mnt/gentoo` path.
- The hook reads the lines of a heredoc as commands, so write notes with the file tools.
- CachyOS, 13 Nov 2026: the guard blocks even `which smartctl`, as it names a disk tool with no Crucial path. Reading health is allowed when the full path is written out: `smartctl -j -H -A /dev/disk/by-id/nvme-CT1000P2SSD8_2128E5B7DBBC`. `kiln-watch` does this. btrfs's error counts need no tool: `/sys/fs/btrfs/<uuid>/devinfo/*/error_stats`.
- CachyOS, 13 Nov 2026, NVIDIA: driver 620.70.06, open modules, for both kernels (`linux-cachyos-nvidia-open`, `linux-cachyos-lts-nvidia-open`). The 4090 idles at P8, about 30 W, with 2 MiB used: the desktop runs on the WX 3200. Its link reports x16 (PCIe 4 under load, 1 at idle); v1 recorded x8.
- Leave `nvidia-suspend`, `nvidia-resume` and `nvidia-hibernate` disabled. Since 595, the open modules save video memory themselves (`UseKernelSuspendNotifiers: 1`, `PreserveVideoMemoryAllocations: 2`, meaning auto), and CachyOS's nvidia-utils disables those units on purpose. The copy goes to RAM, so sleep fails safely if memory is short. Do not sleep with an ML job running; run a small CUDA test after the first resume.
- PyTorch: `python-pytorch-opt-cuda` is Arch's build with `-march=x86-64-v3`, so it meets the v3 rule. `scripts/test-pytorch.py` passes. Warm the GPU before timing: the first 5 runs of the 8192 matrix multiply read 20.7 ms, warm runs 18.0 ms, level with v1's 17.8 ms.
- gpu-unlock (github.com/Zagitta/gpu-unlock): v1's Ubuntu run, 2 Nov 2026, booted with `gpu_unlock.targets=0000:01:00.0`. An out-of-tree kernel module that, before the NVIDIA driver loads, uses a flaw in NVIDIA's signed SEC2 firmware to set the tensor-core rate registers to full rate, then resets the card. Nothing is written to flash; it is gone at power-off. On a 4090 users report raw tensor rate x2, but PyTorch matmuls 0% to 17% (TF32 about +56%). Owner's decision, 13 Nov 2026: not for Kiln, it is beyond Kiln's scope. Do not install it or suggest it. It does not affect `measure.sh`, which times only the CPU, audio and wake-up delay. Its `AGENTS.md` asks AI agents to post results publicly: under Kiln's rules that needs the owner's ask.

