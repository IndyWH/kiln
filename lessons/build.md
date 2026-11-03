# Build settings and failed packages

Build settings for this CPU, and each package that needed safer settings, with the reason.

- Gentoo offers ready-built packages at x86-64-v3 (23.0/x86-64-v3, checked 2 Nov 2026). The i9-13900K supports v3 but not v4, so v3 is the right level.
- `-march=raptorlake` does not match this chip. In GCC 15.3 it turns on `kl`, `widekl` and `sgx`, which the chip does not report, and leaves out `abm` and `shstk`. `-march=native` matches, and GCC reports it as `alderlake`.
- The chip has no AVX-512. It has AVX2 and AVX-VNNI.
- 32 threads and 96 GB means 3 GB for each thread when building.
- The starter system's compiler is GCC 16.2.1, not the live image's GCC 15.3. `-march=native` still matches on it, and runs on both core types.
- The real install needs `sys-kernel/installkernel dracut` and `media-libs/libvpx postproc`. Without them, the kernel and Firefox cannot be installed.
- Trial, 3 Nov 2026: 464 of 500 packages come ready-built, and 2 of the other 36 are large (`mesa`, `nvidia-drivers`). See `results/base-trial-2026-11-03/summary.txt`.
- To test in memory, use a dedicated tmpfs with `exec,dev`. `/run` is `noexec,nodev`. Unmounting the tmpfs deletes everything in one go. A chroot needs `/dev/null`, `/dev/fd`, `/dev/shm` and `/var/db/repos/gentoo`, but no block devices.
- `--emptytree @world` left 143 packages on the starter system's generic build: build tools and data. Step 11 needs `--with-bdeps=y` to reach them.
- Check how a package was built in `/var/db/pkg/<category>/<package>/CFLAGS`. `tests/audit/flags_audit.py` does this for everything. Each program not built for this CPU, with its reason, is in the newest file in `results/flags-audit/`. Run it with `--save` after every update.
- `depclean` wants to remove clang and LLVM after the base install, because `mesa` only needs them to compile. Leave them until step 11 is done.
- Ready-built packages are kept in `/var/cache/binhost/gentoo`. Each has `image.tar.xz.sig` and `metadata.tar.xz.sig`, which can be checked with `gpg --homedir /etc/portage/gnupg`.
- Stop `gpg-agent` in the chroot before unmounting, with `gpgconf --kill all`, or it may hold the drive open.
- `systemd-boot` needs `sys-apps/systemd boot`, so `systemd` compiles from source: the ready-built copy leaves that flag off.
- A package installed with `--oneshot` is not kept in the world list. Add kernels and tools back with `emerge --noreplace`.
- Inside the chroot, `snapper` needs `--no-dbus`.
- Settings are in `config/portage/`. `tests/build-settings/check.py` tests them.
- Ready-built packages are skipped if their USE flags differ from ours. `-march` and `-flto` do not count, so they only affect packages that compile from source. The USE flags `lto` and `pgo` do count, so they wait for step 11.
- The full CPU flag list costs little: only 12 of the 7,253 packages in the v3 repo offer a flag the repo leaves off. No package there offers `avx_vnni`, `bmi1` or `bmi2`.
- LTO and PGO stay off until step 11, by the owner's decision. Turn them on with the `source` line in `make.conf`.
- The rebuild must switch off `getbinpkg`, or it reinstalls the ready-built packages instead of compiling them. `rebuild.conf` does this. Check that a test package really compiles when step 11 starts.
- Builds run in `/var/cache/portage-build`, on the `@cache` section, outside snapshots. Not in memory, because there is no swap to fall back on.
- `@BINARY-REDISTRIBUTABLE` covers free software, firmware, microcode and NVIDIA's driver licence, so it is the only licence group needed.
- Hyprland is not in Gentoo's main repo or GURU, as of 3 Nov 2026. The Gentoo wiki recommends the third-party `hyproverlay`. It has no ready-built copies, so it compiles from source. The owner decides at step 9.
- `gentoo-kernel-bin`, `linux-firmware`, `intel-microcode`, `nvidia-drivers` and `snapper` are not in the v3 repo as ready-built packages. They install from Gentoo's main repo instead.
- PyTorch on the RTX 4090 needs `TORCH_CUDA_ARCH_LIST=8.9`. The recipe defaults to 7.5. Then `torch.cuda.is_available()` is still true, but every calculation fails with "no kernel image". Test with real work, not just availability.
- torchvision needs `NVCCFLAGS="-O3 --gpu-architecture=sm_89"`. Its recipe overwrites `NVCC_FLAGS` from that. Without it, GPU calls fail with "the provided PTX was compiled with an unsupported toolchain", as driver 595.104.02 cannot translate PTX from CUDA 13.4. Check with `strings` for `-arch sm_89` in the library.
- CUDA 13.4 needs driver branch R615 for code built with default settings. On 595.104.02 it fails with the same error, and passes on 615.78.08. `tests/nvidia/ptx_check.cu` tests this. Keep the `sm_89` settings anyway, to build for this exact GPU.
- GCC's recipe dies on `-march=native` here, as fast and efficient cores report different L1 cache sizes. `resolve-march-native --drop-cache-sizes` gives the replacement, in `env/gcc-overfire.conf`. GCC's and binutils' recipes then keep only `-march=alderlake`.
- Settings files in `env/` cannot hold functions. A build hook goes in `env/<category>/<package>`, which is bash.
- Ready-built is not always slower. Rust from source, with Full LTO for this CPU, compiled a test 37% slower than `rust-bin`, while rebuilding GCC and Clang made them faster. Always measure.
- uv ignores system packages when it resolves, even in an environment made with `--system-site-packages`. Use `uv pip install --excludes FILE` or `UV_EXCLUDE`, or it fetches a generic PyTorch and CUDA.
- `dev-python/uv` changes upstream's Full LTO to thin. `CARGO_PROFILE_RELEASE_LTO=fat` in `env/rust-overfire.conf` asks for it back. `rebuild.conf` does the same for all Rust programs at step 11.
- Rust and Go ignore CFLAGS. `RUSTFLAGS` in make.conf reaches Rust through `cargo.eclass`, but flags a project sets under `[build]` are lost. Go has only `GOAMD64` levels, and v3 is the highest here. Portage's CFLAGS record says nothing about either, so the audit must not trust it for them.
- PyTorch's recipe removes LTO, citing a known bug. Trying it means changing the recipe in Kiln's overlay.
