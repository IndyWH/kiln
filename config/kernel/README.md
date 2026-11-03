# The mlrig kernel

`mlrig-6.18.60.config` is the finished config. To build it again, inside the new system, copy it to `/usr/src/linux-6.18.60-gentoo/.config`, then run `make olddefconfig`, `make -j32 -l32`, `make modules_install` and `make install`.

How the config was made, in order:

1. Start from Gentoo's own, in `/usr/src/linux-6.18.60-gentoo-dist-bin/.config`, with `make olddefconfig`.
2. Cut it down with `make LSMOD=modules-mlrig.txt localmodconfig`. The list is what the live system loaded, minus what only the live image uses, such as `nouveau` and iSCSI. Added by hand: FAT, what VM software needs, and `scsi_debug` for the guard test. `btrfs` is built in, from Gentoo's config.
3. Change these with `scripts/config`:

| Setting | Why |
|---|---|
| `LOCALVERSION=-mlrig` | Tells the two kernels apart |
| `PREEMPT`, `PREEMPT_DYNAMIC`, `HZ_1000` | Desktop-friendly scheduling |
| `X86_NATIVE_CPU` | Builds for this exact CPU. This kernel will not run on another CPU type |
| `SCHED_MC`, `SCHED_MC_PRIO`, `INTEL_HFI_THERMAL`, `X86_INTEL_PSTATE`, `INTEL_TURBO_MAX_3` | Fast and efficient core placement |
| No `DRM_NOUVEAU` | The RTX 4090 uses NVIDIA's driver |
| No `SECURITY_LOCKDOWN_LSM`, `MODULE_SIG` | Secure Boot is out of scope, and lockdown forces signing on |
| No `DEBUG_INFO` | Smaller and quicker to build |

After any rebuild of this kernel, run `emerge @module-rebuild` to rebuild the NVIDIA driver.
