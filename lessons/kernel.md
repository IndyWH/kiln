# Kernel

The mlrig kernel config, and what was learnt building it.

- The kernel warns `Running old microcode` at revision 0x12f, from the BIOS. The live image has no microcode file for this chip. Gentoo's package holds 0x137 (18 Feb 2026), and is installed on the Crucial. Check the warning has gone at first boot.
- Fast cores are threads 0 to 15, efficient cores 16 to 31. The chip reports `hfi`, so keep the Intel hybrid scheduling support on.
- Driver list: see Kernel needs in `docs/HARDWARE.md`.
- The owner wants the NVIDIA driver, for ML work, and the `cp210x` driver for the USB serial adapter, at low priority. It runs GermOS on the HP.
