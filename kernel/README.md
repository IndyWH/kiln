# Kiln's own kernel

`linux-cachyos-kiln`: CachyOS's kernel, built here at the strongest settings. BORE scheduler, Clang full LTO, -O3, x86-64-v3, and profiles taken on this machine (AutoFDO, then Propeller). The stock `linux-cachyos` and the rescue `linux-cachyos-lts` stay installed and in the boot menu.

- `PKGBUILD.cachyos`: CachyOS's build script, unchanged, from github.com/CachyOS/linux-cachyos at commit 8c1b372 (13 Nov 2026). `config` is from the same commit.
- `PKGBUILD`: Kiln's copy; `kiln.patch` shows every change. Its own name; no exact nvidia-utils version, so driver updates never block a system update; checksums for every download.
- `build.sh 1|2|3`: builds as the owner in ~/.cache/kiln-kernel/stageN. Installing is separate.

## Costs

- After an nvidia-utils update, the 4090 does not work on this kernel until it is rebuilt. The desktop's card and the stock kernels are not affected. `kiln-watch` reports it.
- This kernel does not update with `pacman -Syu`; the stock one does. Rebuild to catch up.

## Backing out

Snapshots do not cover /boot, so `undo` and `restore` do not remove a kernel. Instead:

    sudo pacman -R linux-cachyos-kiln-nvidia-open linux-cachyos-kiln-dbg linux-cachyos-kiln-headers linux-cachyos-kiln

Then, if it was changed, put `BOOT_ORDER` in /etc/default/limine back to `"*, *lts, *fallback, Snapshots"` and run `sudo limine-update`.

## The Propeller tool

`generate_propeller_profiles`, built as the owner in ~/.cache/kiln-kernel/propeller-src from github.com/google/llvm-propeller at commit e98f399 (12 Nov 2026). Reviewer: CONCERNS, answered. Its downloads have no checksums in its build; recorded here on 14 Nov 2026, and Quipper's matches the one the project keeps for Bazel:

| Download | SHA-256 |
|---|---|
| LLVM, commit 260f2eb1 | 644daff85b1d258f48e2031521189da2cc5b9658e0614e4fd1042eadc1c6d397 |
| Quipper, commit f9eb05fc | 5c747832c94d358847c3b29c5f837271e40b980f7629a95c618eba3817c77679 |
| Abseil 20260107.1 | 05597c3c532197690a31ebad50a7c9c3fb682d3c5a681b20eb03655ffb4e9483 |
| Googletest 1.17.0 | 40d4ec942217dcc84a9ebe2a68584ada7d4a33a8ee958755763278ea1c5e18ff |
| Protobuf 33.4 | bc670a4e34992c175137ddda24e76562bb928f849d712a0e3c2fb2e19249bea1 |

    cmake -G Ninja -S repo -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_USE_STATIC_ZSTD=OFF
    ninja -C build generate_propeller_profiles

The kernel's own propeller.rst shows older options (`--format`, `--out`); this version takes `--cc_profile`, `--ld_profile` and `--propeller_options='output_module_name: true'`.
