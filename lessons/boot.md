# Boot

The boot loader, firmware entries and start-up.

- Firmware takes about 15.6 seconds before any operating system runs. Report it separately from boot time.
- The system starts in UEFI mode, on ASUS BIOS 3107.
- Owner's decision, 3 Nov 2026: Ubuntu stays first in the boot order. The owner presses F8 and chooses the Crucial to start Kiln.
- The new system's `/boot` already holds `intel-uc.img` and `amd-uc.img`, from the microcode packages. The boot loader must load `intel-uc.img` first.
- Before Kiln's first boot, the disk guard must be on Kiln itself, because a fresh boot has no locks.
- Installing a boot loader normally puts itself first in the boot order. After installing Kiln's, set the order back so Ubuntu is first, and read it back.
- Pressing F8 adds waiting time to the firmware part of the boot figures, so report firmware time separately, as the spec already says.
