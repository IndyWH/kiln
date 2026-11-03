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
- Booting a past snapshot from the menu is not built yet. It belongs to step 10.
- Set `/etc/resolv.conf` to the `systemd-resolved` link last. It points at nothing inside a chroot, so DNS stops working there.
