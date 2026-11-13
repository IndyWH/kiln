# Packages

Package repos, CPU level and building from source on CachyOS.

- Owner's rule, 13 Nov 2026: CachyOS's x86-64-v3 packages whenever they exist; otherwise wait for CachyOS. Anything built from source, such as from the AUR, uses `-march=x86-64-v3`. No benchmark needed. The i9-13900K has no AVX-512, so v4 is not an option.
- pacman follows the rule by itself. The v3 repos come first in `/etc/pacman.conf`, and CachyOS numbers a v3 build with an extra `.1` (`5.05-6.1` against Arch's `5.05-6`), so an update moves a generic package to v3 once the v3 build exists. Tested with `sl` on 13 Nov 2026.
- `kiln-v3` (from `scripts/kiln-v3`) lists what is still generic. On 13 Nov 2026: 825 v3 builds, 144 with no CPU code (`any`), 72 generic with no v3 build yet (systemd, openssl, ffmpeg, pipewire and others, several of them fresh releases), and 49 32-bit `lib32-` libraries, to which v3 does not apply.
- CachyOS's `/etc/makepkg.conf` uses `-march=native` and `target-cpu=native`. `/etc/makepkg.conf.d/zz-kiln-x86-64-v3.conf`, copy in `config/makepkg/`, swaps them for x86-64-v3 and keeps CachyOS's other flags (`-O3`, LTO, hardening). makepkg reads `makepkg.conf.d/*.conf` in alphabetical order after the main file, so `zz-` loads last, and pacman updates leave it alone.
- CachyOS's GCC 16.2 is built with `bootstrap-lto`. No BOLT marks in its Clang 23.1 or `libLLVM`. Whether either uses PGO cannot be seen from the files.
- The disk guard reads every script a command sources. It blocks sourcing `/etc/makepkg.conf`, as its download commands cannot be checked, and a script named through a variable such as `$S/x.sh`. Copy the needed lines to a scratch file in one command, then run it by its full path in the next.
