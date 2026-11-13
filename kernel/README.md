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
