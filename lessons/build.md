# Build settings and failed packages

Build settings for this CPU, and each package that needed safer settings, with the reason.

- Gentoo offers ready-built packages at x86-64-v3 (23.0/x86-64-v3, checked 2 Nov 2026). The i9-13900K supports v3 but not v4, so v3 is the right level.
- `-march=raptorlake` does not match this chip. In GCC 15.3 it turns on `kl`, `widekl` and `sgx`, which the chip does not report, and leaves out `abm` and `shstk`. `-march=native` matches, and GCC reports it as `alderlake`.
- The chip has no AVX-512. It has AVX2 and AVX-VNNI.
- 32 threads and 96 GB means 3 GB for each thread when building.
- Settings are in `config/portage/`. `tests/build-settings/check.py` tests them.
- Ready-built packages are skipped if their USE flags differ from ours. `-march` and `-flto` do not count, so they only affect packages that compile from source. The USE flags `lto` and `pgo` do count, so they wait for step 11.
- The full CPU flag list costs little: only 12 of the 7,253 packages in the v3 repo offer a flag the repo leaves off. No package there offers `avx_vnni`, `bmi1` or `bmi2`.
- LTO and PGO stay off until step 11, by the owner's decision. Turn them on with the `source` line in `make.conf`.
- The rebuild must switch off `getbinpkg`, or it reinstalls the ready-built packages instead of compiling them. `rebuild.conf` does this. Check that a test package really compiles when step 11 starts.
- Builds run in `/var/cache/portage-build`, on the `@cache` section, outside snapshots. Not in memory, because there is no swap to fall back on.
- `@BINARY-REDISTRIBUTABLE` covers free software, firmware, microcode and NVIDIA's driver licence, so it is the only licence group needed.
- Hyprland is not in Gentoo's main repo or GURU, as of 3 Nov 2026. The Gentoo wiki recommends the third-party `hyproverlay`. It has no ready-built copies, so it compiles from source. The owner decides at step 9.
- `gentoo-kernel-bin`, `linux-firmware`, `intel-microcode`, `nvidia-drivers` and `snapper` are not in the v3 repo as ready-built packages. They install from Gentoo's main repo instead.
