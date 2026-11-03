# Boot

The boot loader, firmware entries and start-up.

- Firmware takes about 15.6 seconds before any operating system runs. Report it separately from boot time.
- The system starts in UEFI mode, on ASUS BIOS 3107.
- Owner's decision, 3 Nov 2026: Ubuntu stays first in the boot order. The owner presses F8 and chooses the Crucial to start Kiln.
- The new system's `/boot` already holds `intel-uc.img` and `amd-uc.img`, from the microcode packages. The boot loader must load `intel-uc.img` first.
- Before Kiln's first boot, the disk guard must be on Kiln itself, because a fresh boot has no locks.
- Installing a boot loader normally puts itself first in the boot order. After installing Kiln's, set the order back so Ubuntu is first, and read it back.
- Pressing F8 adds waiting time to the firmware part of the boot figures, so report firmware time separately, as the spec already says.
- Boot loader: `systemd-boot`. It only looks at its own drive. Install with `bootctl --esp-path=/boot --no-variables install`, which leaves firmware settings alone.
- `efibootmgr --create-only` adds an entry without adding it to the boot order. Boot entry 0001 is `Kiln`. Whether F8 shows it is checked at first boot. The fallback copy may also show as `UEFI OS`.
- To keep the chroot away from firmware settings, use `mount --bind /sys`, not `--rbind`. Then `/sys/firmware/efi/efivars` is empty inside.
- To prove a boot entry is stale, look up its partition's GUID in `/dev/disk/by-partuuid/`. No disk is opened.
- The kernel options are in `/etc/kernel/cmdline`, and `kernel-install` copies them into each entry. They switch off LVM, RAID and encryption at start-up, because the locks are not on yet at that stage.
- Each kernel entry loads `microcode-amd`, `microcode-intel`, then `initrd`. `kernel-install` adds the first two. The Intel file is 28 MB, for every Intel chip, and could be cut down at step 12.
- The boot partition has no snapshots. Snapshots of the main system do not include kernels on `/boot`.
- Past snapshots in the menu: `kiln_snapshots.py menu` writes an entry for each of the 5 newest before and single snapshots, plus the 3 newest milestones, using the mlrig kernel. It skips any without the disk guard or that kernel's drivers. A systemd path unit runs it when `/.snapshots` changes. Marking an existing snapshot as a milestone does not trigger it, so start `kiln-snapshot-menu.service` by hand after that. Entries are `kiln-snapshot-*.conf`, so the `*-mlrig*` default never matches them. They boot read-only. Not yet booted, so whether the desktop starts this way is still to be tested.
- Set `/etc/resolv.conf` to the `systemd-resolved` link last. It points at nothing inside a chroot, so DNS stops working there.
- First boot, 3 Nov 2026: the `Kiln` firmware entry was gone by the next live start. Entry 0001 is now `UEFI OS`, on the Crucial boot partition, and second in the order. No session removed it, so the firmware probably replaced it. Rely on the fallback copy, and read the entries by partition, not by name.
- The first-boot guard test counts writes to the Crucial, so it always fails when run from Kiln, because a running Kiln writes to its own drive. Only that one line fails. The line for the other disks is the one that matters.
