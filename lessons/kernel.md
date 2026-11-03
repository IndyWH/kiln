# Kernel

The mlrig kernel config, and what was learnt building it.

- The kernel warns `Running old microcode` at revision 0x12f, from the BIOS. The live image has no microcode file for this chip. Gentoo's package holds 0x137 (18 Feb 2026), and is installed on the Crucial. Check the warning has gone at first boot.
- Fast cores are threads 0 to 15, efficient cores 16 to 31. The chip reports `hfi`, so keep the Intel hybrid scheduling support on.
- Driver list: see Kernel needs in `docs/HARDWARE.md`.
- The owner wants the NVIDIA driver, for ML work, and the `cp210x` driver for the USB serial adapter, at low priority. It runs GermOS on the HP.
- Two kernels, both 6.18.60: `6.18.60-gentoo-mlrig` and the rescue `6.18.60-gentoo-dist-bin`. How the config was made: `config/kernel/README.md`. It compiles in about 3 minutes.
- `localmodconfig` only keeps what was loaded when the list was taken. The live list had no FAT or VM parts, and did have `nouveau` and iSCSI. Fix the list by hand.
- `SECURITY_LOCKDOWN_LSM` forces `MODULE_SIG` on. Turn off both, or neither.
- `nvidia-drivers` builds for the kernel `eselect kernel` points at, so only the mlrig kernel has it. Keep that pointing at `linux-6.18.60-gentoo`. After rebuilding that kernel, run `emerge @module-rebuild`.
- `nvidia-drivers` 595 has no `kernel-open` flag, because the open module is the only choice. `modinfo` shows licence `Dual MIT/GPL`.
- `nvidia-drivers` 595.104.02 says it supports kernels up to 7.3.
- Extra kernels: `sudo scripts/build-kernel.sh SOURCE gcc|clang`. They are named `-kiln-`, never `-mlrig`, so the `*-mlrig*` default cannot pick one. Each keeps its own build folder in `/usr/src/kiln-kernel/`, and the `/usr/src/linux` link stays on 6.18. They have no NVIDIA driver.
- Clang 22 is installed for Mesa but is not on the PATH. A kernel build uses `LLVM=/usr/lib/llvm/22/bin/`.
- A world entry with no slot keeps only the newest kernel source, so name each kernel's slot in the world file: `sys-kernel/gentoo-sources:6.18.60`.
- Module file names use hyphens, such as `snd-hda-intel.ko`, so searching with underscores finds nothing.
