#!/usr/bin/env bash
# One command to bring Kiln's own kernel up to CachyOS's latest, at the same settings.
# Each run does the next step and says what comes after. Run as the owner, never with sudo;
# it asks sudo only to install the packages and to record the profiles.
#
#   kernel/rebuild.sh                   the next step
#   kernel/rebuild.sh status            where a rebuild is up to
#   kernel/rebuild.sh reviewed [--full] go on, after the reviewer has read the review file
#   kernel/rebuild.sh back              put back the last good Kiln kernel, then restart
#   kernel/rebuild.sh cancel            forget a rebuild waiting for review
#   kernel/rebuild.sh seed              record the installed stage 3 kernel as the last good one
#
# A new kernel version takes all three stages, so three restarts:
#   check    fetch CachyOS's build scripts; if they changed, make Kiln's PKGBUILD from them,
#            check every download that has no checksum, write a review file, and stop.
#   reviewed build and install stage 1. Restart.
#   boot 1   check the restart; record on stage 1 (AutoFDO); build and install stage 2. Restart.
#   boot 2   check; record on stage 2 (Propeller); build and install stage 3. Restart.
#   boot 3   check; keep the packages as the last good kernel, and the profiles for next time.
# A new NVIDIA driver alone (kernel source, config, BORE, compiler and build steps unchanged)
# reuses the saved profiles: stage 3 only, one restart.
#
# Every stage is built from the reviewed copies in rebuild/build-files, never from the repo's
# working tree, so an edit or branch switch between restarts cannot slip in.
set -euo pipefail
export LC_ALL=C

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# Runs from the repo folder and names its helpers as kernel/..., so that Claude's disk guard,
# which reads a script before it runs and cannot follow paths held in variables, can check
# them. Claude runs it from the repo folder too.
cd "$here/.."
K=${KILN_KERNEL_CACHE:-$HOME/.cache/kiln-kernel}
R=$K/rebuild
UP=$K/upstream                      # CachyOS's linux-cachyos repository
UPSTREAM_URL=https://github.com/CachyOS/linux-cachyos.git
PROPELLER_TOOL=$K/propeller-src/build/propeller/generate_propeller_profiles
PROFILES=$K/profiles/current        # kiln.afdo, propeller_*_profile.txt, fingerprint
LAST_GOOD=$K/last-good              # the last kernel that passed every check: its packages,
                                    # and the build files and CachyOS commit it was made from
FILES=$R/build-files                # the reviewed build files every stage is built from
STATE=$R/state
PACKAGES=(linux-cachyos-kiln linux-cachyos-kiln-dbg linux-cachyos-kiln-headers linux-cachyos-kiln-nvidia-open)
# The settings build.sh uses, for listing the downloads the same way. Keep the two alike.
KILN_ENV=(_cpusched=bore _use_llvm_lto=full _processor_opt=generic_v3 _cc_harder=yes
          _build_nvidia_open=yes _build_debug=yes _autofdo=yes)
NVIDIA_SRC=https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/
CACHYOS_PATCHES=https://raw.githubusercontent.com/cachyos/kernel-patches/master/

printf -v nl "\n"; printf -v tab "\t"
say() { printf '%s\n' "$*"; }
die() { printf 'Stopped: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" != 0 ] || die "run as the owner, not with sudo"
case $K in ""|/|"$HOME"|"$HOME/") die "KILN_KERNEL_CACHE must be its own folder" ;; esac
# A test cache may only be checked: build.sh and the installs always use the real one.
if [ -n "${KILN_KERNEL_CACHE:-}" ]; then
    case ${1:-next} in next|status|cancel|fingerprint) ;; *) die "with KILN_KERNEL_CACHE set, only check, status and cancel" ;; esac
fi
mkdir -p "$R/log"
if [ -n "${KILN_KERNEL_CACHE:-}" ] && [ "${1:-next}" = next ]; then
    case $(sed -n 's/^step=//p' "$R/state" 2>/dev/null | tail -1) in ""|none|review) ;; *) die "a test cache cannot go past review" ;; esac
fi

# State: key=value lines. step is one of: none, review, boot1, boot2, boot3.
get() { [ -f "$STATE" ] && sed -n "s/^$1=//p" "$STATE" | tail -1 || true; }
put() {  # put key=value ..., all in one replace
    local kv tmp; tmp=$(mktemp "$R/.state.XXXX")
    [ -f "$STATE" ] && cp "$STATE" "$tmp"
    for kv in "$@"; do sed -i "/^${kv%%=*}=/d" "$tmp"; printf '%s\n' "$kv" >> "$tmp"; done
    mv "$tmp" "$STATE"
}
step=$(get step); step=${step:-none}

# makepkg runs a PKGBUILD's top level as code. A freshly fetched one is read only inside a
# sandbox with no network and nothing writable, before anyone has reviewed it.
srcinfo() {  # folder file
    # The owner's home, /run (D-Bus, ssh and gpg agents) and the environment are hidden too.
    bwrap --ro-bind / / --dev-bind /dev/null /dev/null --proc /proc --tmpfs /tmp \
        --tmpfs /run --tmpfs "$HOME" --ro-bind "$1" "$1" \
        --unshare-all --new-session --die-with-parent --clearenv --chdir "$1" \
        /usr/bin/env PATH=/usr/bin HOME=/tmp BUILDDIR=/tmp/b SRCDEST=/tmp/s PKGDEST=/tmp/p \
        SRCPKGDEST=/tmp/sp LOGDEST=/tmp/l "${KILN_ENV[@]}" makepkg -p "$2" --printsrcinfo
}

# What decides whether the saved profiles still fit: everything that goes into the kernel
# itself. Lines about NVIDIA and pkgrel are left out, as they change only the NVIDIA module.
fingerprint() {  # folder with PKGBUILD.cachyos, config and bore.b2sum
    local info; info=$(srcinfo "$1" PKGBUILD.cachyos)
    {
        printf 'kernel %s\n' "$(sed -n 's/^\tpkgver = //p' <<<"$info")"
        sed -n 's/^\tb2sums = //p' <<<"$info"        # CachyOS's own: kernel source, config, patches
        grep -viE 'nvidia|_nv_|^pkgrel=' "$1/PKGBUILD.cachyos" | b2sum | cut -d' ' -f1
        b2sum "$1/config" | cut -d' ' -f1
        cat "$1/bore.b2sum" 2>/dev/null || true
        for f in kiln.patch kiln-tail.sh kiln-lto-profiles.patch build.sh; do
            printf '%s %s\n' "$f" "$(b2sum "$here/$f" | cut -d' ' -f1)"
        done
        pacman -Q clang llvm lld rust
    }
}

# Kiln's PKGBUILD = CachyOS's + kiln.patch + kiln-tail.sh with the checksums filled in.
make_pkgbuild() {  # folder nvidia_sums bore_sum
    local d=$1 out info
    out=$(patch --no-backup-if-mismatch -o "$d/PKGBUILD" -i "$here/kiln.patch" "$d/PKGBUILD.cachyos" 2>&1) ||
        die "kiln.patch no longer fits CachyOS's new build script; update it by hand, reviewer first.
$out"
    printf '%s\n' "$out" > "$d/patch.out"
    sed -e "s|@NVIDIA_SUMS@|$2|" -e "s|@BORE_SUM@|'$3'|" \
        -e "s|@LTO_SUM@|$(b2sum "$here/kiln-lto-profiles.patch" | cut -d' ' -f1)|" \
        "$here/kiln-tail.sh" >> "$d/PKGBUILD"
    cp "$here/kiln-lto-profiles.patch" "$d/"
    info=$(srcinfo "$d" PKGBUILD)
    grep -qx "pkgbase = linux-cachyos-kiln" <<<"$info" || die "the new PKGBUILD's name is not linux-cachyos-kiln"
    if grep -q "^${tab}replaces = " <<<"$info"; then die "the new PKGBUILD replaces another package"; fi
}

check() {
    say "Fetching CachyOS's build scripts..."
    [ -d "$UP/.git" ] || git clone -q --filter=blob:none "$UPSTREAM_URL" "$UP"
    git -C "$UP" fetch -q origin
    local new old n d=$R/new
    new=$(git -C "$UP" rev-parse origin/master)
    old=$(cat "$LAST_GOOD/upstream-commit" 2>/dev/null) || die "no last good kernel recorded in $LAST_GOOD"
    rm -rf "${R:?}/new"; mkdir -p "$d/dl"
    git -C "$UP" show "$new:linux-cachyos/PKGBUILD" > "$d/PKGBUILD.cachyos"
    git -C "$UP" show "$new:linux-cachyos/config" > "$d/config"
    if cmp -s "$d/PKGBUILD.cachyos" "$LAST_GOOD/PKGBUILD.cachyos" && cmp -s "$d/config" "$LAST_GOOD/config"; then
        local rel mod utils kiln
        kiln=$(pacman -Q linux-cachyos-kiln 2>/dev/null || echo "not installed")
        say "Nothing new: CachyOS's kernel build is the one Kiln's kernel was made from (CachyOS commit ${new:0:7})."
        say "Kiln's kernel: $kiln."
        rel=$(awk '{print $2}' <<<"$kiln")-cachyos-kiln
        mod=$(modinfo -k "$rel" -F version nvidia 2>/dev/null || true)
        utils=$( (pacman -Q nvidia-utils 2>/dev/null || true) | awk '{print $2}' | cut -d- -f1)
        [ "$mod" = "$utils" ] || say "Its NVIDIA module is ${mod:-missing} and the driver ${utils:-missing}: CachyOS has not yet updated its kernel build for that driver. Try again in a day or two."
        rm -rf "${R:?}/new"; return 0
    fi
    say "CachyOS's build changed: commit ${old:0:7} to ${new:0:7}. Checking the downloads..."

    local info ver; info=$(srcinfo "$d" PKGBUILD.cachyos)
    mapfile -t srcs < <(sed -n 's/^\tsource = //p' <<<"$info")
    mapfile -t sums < <(sed -n 's/^\tb2sums = //p' <<<"$info")
    n=${#sums[@]}
    ver=$(sed -n 's/^\tpkgver = //p' <<<"$info")-$(sed -n 's/^\tpkgrel = //p' <<<"$info")
    local i url f want got bore_info nv_sums="" bore_sum="" checks=""
    for ((i = 0; i < n; i++)); do
        [ "${sums[i]}" != SKIP ] || [[ ${srcs[i]} == *.asc ]] || die "CachyOS skips the checksum of ${srcs[i]}"
    done
    bore_info=$(git -C "$UP" show "$new:linux-cachyos-bore/.SRCINFO")
    for ((i = n; i < ${#srcs[@]}; i++)); do
        url=${srcs[i]}; f=$d/dl/$(basename "$url")
        case $url in *..*) die "a download address with .. in it: $url" ;; esac
        case $url in
        "$NVIDIA_SRC"NVIDIA-kernel-module-source-*.tar.xz|"$CACHYOS_PATCHES"*/misc/nvidia/*.patch|"$CACHYOS_PATCHES"*/sched/0001-bore-cachy.patch) ;;
        *) die "a new download without a checksum, which rebuild.sh does not know: $url" ;;
        esac
        curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 --max-time 600 -o "$f" "$url" ||
            die "could not download $url"
        got=$(b2sum "$f" | cut -d' ' -f1)
        case $url in
        *.tar.xz)
            want=$(curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 "$url.sha256sum" | awk '{print $1}') ||
                die "no NVIDIA checksum for $url"
            [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$want" ] || die "$url does not match NVIDIA's published SHA-256"
            checks="$checks- $url: matches the SHA-256 NVIDIA publishes beside it ($want). That sum comes from the same server, so it shows the download is whole, not that the server is honest.$nl"
            nv_sums="$nv_sums'$got' " ;;
        */misc/nvidia/*)
            checks="$checks- $url: CachyOS's patch, no published sum; diff below.$nl"
            nv_sums="$nv_sums'$got' " ;;
        *)
            # CachyOS's own sum: the b2sum at the same position as this source in the BORE variant's .SRCINFO
            want=$(awk -v u="$url" '$1=="source"{s++; if ($3==u) k=s} $1=="b2sums"{b++; if (b==k) print $3}' <<<"$bore_info")
            [ -n "$want" ] && [ "$got" = "$want" ] || die "the BORE patch does not match CachyOS's sum in linux-cachyos-bore/.SRCINFO"
            checks="$checks- $url: matches CachyOS's sum in linux-cachyos-bore/.SRCINFO; diff below.$nl"
            printf '%s\n' "$got" > "$d/bore.b2sum"
            bore_sum=$got ;;
        esac
    done
    [ -n "$bore_sum" ] || die "no BORE patch among the downloads"
    make_pkgbuild "$d" "${nv_sums% }" "$bore_sum"
    printf '%s\n' "$new" > "$d/upstream-commit"

    # Quick (stage 3 only) if everything that goes into the kernel itself is as when the
    # saved profiles were made.
    local mode=full why stock
    fingerprint "$d" > "$d/fingerprint"
    if [ -f "$PROFILES/fingerprint" ] && cmp -s "$d/fingerprint" "$PROFILES/fingerprint"; then
        mode=quick; why="only the NVIDIA module changed, so the saved profiles still fit"
    else
        why=$(diff "$PROFILES/fingerprint" "$d/fingerprint" 2>&1 | grep '^[<>]' | head -12 || true)
        why="these changed since the saved profiles were made:$nl$why"
    fi
    stock=$( (pacman -Q linux-cachyos 2>/dev/null || echo "? none") | awk '{print $2}')

    # The review file: everything the reviewer needs, nothing concluded.
    local rf=$R/review-$ver.txt
    {
        say "Kiln kernel rebuild: CachyOS's git $ver, commit $new (Kiln's was $old)."
        say "CachyOS's released stock kernel, installed: linux-cachyos $stock. Kiln's kernel installed: $( (pacman -Q linux-cachyos-kiln 2>/dev/null || echo none) )."
        say "Mode: $mode, $why"
        say; say "CachyOS's commits to linux-cachyos since Kiln's:"
        git -C "$UP" log --format='  %h %ci %s' "$old..$new" -- linux-cachyos
        say; say "Downloads without a CachyOS checksum:"; printf '%s' "$checks"
        say; say "kiln.patch applied:"; cat "$d/patch.out"
        for f in "$d"/dl/*.patch; do
            say; say "== $(basename "$f"), against the copy reviewed last time:"
            if [ -f "$R/reviewed/$(basename "$f")" ]; then
                diff -u "$R/reviewed/$(basename "$f")" "$f" || true
            else
                say "(new; no reviewed copy)"; cat "$f"
            fi
        done
        say; say "== CachyOS's PKGBUILD, old to new:"; diff -u "$LAST_GOOD/PKGBUILD.cachyos" "$d/PKGBUILD.cachyos" || true
        say; say "== Kiln's PKGBUILD, old to new:"; diff -u "$LAST_GOOD/PKGBUILD" "$d/PKGBUILD" || true
        say; say "== config, old to new:"; diff -u "$LAST_GOOD/config" "$d/config" || true
    } > "$rf"
    put step=review version="$ver" mode="$mode" review="$rf"
    say "Ready for review: $rf"
    say "Mode: $mode. Have the reviewer read it, then run: kernel/rebuild.sh reviewed"
}

pkgs_in() {  # folder: sets PKGS to the four package files, or stops (in this shell, not a side one)
    local p f
    PKGS=()
    for p in "${PACKAGES[@]}"; do
        f=""
        for f in "$1/$p"-[0-9]*.pkg.tar.zst; do :; done
        [ -f "$f" ] || die "not all four packages are in $1 ($p is missing)"
        PKGS=("${PKGS[@]}" "$f")
    done
    [ "${#PKGS[@]}" = 4 ] || die "not all four packages are in $1"
}

# The boot partition: room before an install; after it, Kiln's and the rescue kernel's
# entries in the menu, their files present, and Kiln's the one just installed.
boot_room() {
    local free; free=$(df -m --output=avail /boot | tail -1 | tr -d ' ')
    [ "$free" -ge 400 ] || die "only $free MB free on /boot. Nothing was installed. Ask Claude to make room (old boot-menu snapshot kernels in /boot/*/limine_history are the usual cause), then run this again."
}
boot_files() {  # Limine's layout: /boot/<machine-id>/<kernel>/vmlinuz and initramfs
    local rel=$1 e f advice="Do not restart into Kiln's kernel; ask Claude to look into it, or run kernel/rebuild.sh back. The stock and rescue kernels are untouched."
    for e in linux-cachyos-kiln linux-cachyos-lts; do
        sudo grep -qE "^[[:space:]]*//$e[[:space:]]*\$" /boot/limine.conf || die "$e is missing from the boot menu. $advice"
        for f in vmlinuz initramfs; do
            [ -n "$(sudo find /boot -path "*/$e/$f" -size +1M)" ] || die "$e's $f is missing from /boot. $advice"
        done
    done
    sudo find /boot -path '*/linux-cachyos-kiln/vmlinuz' -exec cmp -s {} "/usr/lib/modules/$rel/vmlinuz" ';' -print |
        grep -q . || die "the kernel in /boot is not the one just installed. $advice"
}
# Before each build: the scripts that run it are the ones reviewed. A newer compiler
# changes only how well the profiles fit, so it is reported, not stopped for.
same_tools() {
    [ "$(b2sum kernel/build.sh kernel/profile.sh)" = "$(cat "$FILES/tools.b2sum")" ] ||
        die "kernel/build.sh or kernel/profile.sh changed since the review; review again, then kernel/rebuild.sh reviewed"
    [ "$(pacman -Q clang llvm lld rust)" = "$(cat "$FILES/compiler")" ] ||
        say "Note: the compiler was updated since the review; the profiles may fit a little less well."
}

install_stage() {  # stage
    local dir=$K/stage$1 log=$R/log/install-stage$1.log rel
    pkgs_in "$dir"
    boot_room
    say "Installing stage $1..."
    sudo pacman -U --noconfirm "${PKGS[@]}" > "$log" 2>&1 || die "install failed; see $log"
    if grep -E 'ERROR|^error:' "$log"; then
        die "the install reported errors (above; $log). Do not restart into Kiln's kernel; run kernel/rebuild.sh back"
    fi
    rel=$(pacman -Q linux-cachyos-kiln | awk '{print $2}')-cachyos-kiln
    boot_files "$rel"
    put step="boot$1" installed_stage="$1" installed_at="$(date +%s)" built= \
        boot_id="$(cat /proc/sys/kernel/random/boot_id)"
}

build_stage() {  # stage [args for build.sh]
    local s=$1 log=$R/log/build-stage$1.log; shift
    same_tools
    rm -rf "${K:?}/stage$s"
    say "Building stage $s, about 20 minutes, from $(date +%H:%M). Log: $log"
    KILN_BUILD_FILES=$FILES kernel/build.sh "$s" "$@" > "$log" 2>&1 ||
        die "stage $s did not build; last lines of $log:$nl$(tail -15 "$log")"
    put built="$s"
}

# After a restart: the stage just installed is the one running, and the machine is well.
check_boot() {  # stage expected to be running
    local rel bad=""
    [ "$(get installed_stage)" = "$1" ] || die "the state says stage $(get installed_stage) is installed, not $1; see kernel/rebuild.sh status"
    [ "$(cat /proc/sys/kernel/random/boot_id)" != "$(get boot_id)" ] ||
        die "restart first; stage $1 is installed but not running yet."
    rel=$(pacman -Q linux-cachyos-kiln | awk '{print $2}')-cachyos-kiln
    [ "$(uname -r)" = "$rel" ] || die "running $(uname -r), not Kiln's $rel.
If it was picked by hand, restart and leave the menu on Kiln. If Kiln's kernel did not start,
put the last good one back: kernel/rebuild.sh back"
    grep -aqF "$(uname -v)" "/usr/lib/modules/$rel/vmlinuz" ||
        die "the running kernel is not the build just installed ($(uname -v)); restart into Kiln's kernel"
    local failed; failed=$(systemctl --failed --plain --no-legend | awk '{print $1}' | xargs)
    [ -z "$failed" ] || bad="${bad}failed services: $failed. "
    nvidia-smi -L 2>/dev/null | grep -q 'RTX 4090' || bad="${bad}the 4090 is not working (nvidia-smi). "
    [ "$(sudo python3 /usr/local/lib/kiln-guard/kiln_guard.py status 2>&1 | tail -1)" = "Result: OK" ] ||
        bad="${bad}the disk guard is not OK. "
    [ -z "$bad" ] || die "stage $1 started, but $bad
Look into it, or put the last good kernel back: kernel/rebuild.sh back"
    say "Stage $1 is running and well: $(uname -r), no failed services, 4090 and guard OK."
}

profile() {  # out_dir workload_stage [propeller tool]
    local log; log=$R/log/profile-$(basename "$1").log
    rm -rf "${1:?}"
    say "Recording the profile during a kernel build, about 10 minutes. Log: $log"
    sudo kernel/profile.sh "$1" "$(ls -d "$K/stage$2"/src/cachyos-*/)" ${3:+"$3"} > "$log" 2>&1 ||
        die "recording failed; last lines of $log:$nl$(tail -15 "$log")"
}

restart_now() {
    say "Done: stage $1 installed, the default in the boot menu."
    say "Now restart, leave the menu on Kiln's kernel, and run kernel/rebuild.sh again."
}

replace_dir() {  # new_folder target: swap in whole, never leave a half-made one
    rm -rf "${2:?}.old"
    [ ! -e "$2" ] || mv "$2" "$2.old"
    mv "$1" "$2"
    rm -rf "${2:?}.old"
}

reviewed() {
    [ "$step" = review ] || die "nothing waiting for review (step: $step)"
    pkgs_in "$LAST_GOOD"
    local mode d=$R/new first; mode=$(get mode); [ "${1:-}" = --full ] && mode=full
    first=1; [ "$mode" = quick ] && first=3
    if [ "$(get built)" = "$first" ]; then  # built, but the install stopped: install again
        say "Stage $first is already built from the reviewed files."
        install_stage "$first"; restart_now "$first"; return
    fi
    # Again now, as the compiler may have been updated since the check.
    fingerprint "$d" > "$d/fingerprint"
    if [ "$mode" = quick ] && ! cmp -s "$d/fingerprint" "$PROFILES/fingerprint"; then
        mode=full; say "Something changed since the check (the compiler?): a full rebuild."
    fi
    # The reviewed files: every stage is built from these copies.
    rm -rf "${R:?}/build-files.new"; mkdir -p "$FILES.new"
    cp "$d"/{PKGBUILD.cachyos,PKGBUILD,config,kiln-lto-profiles.patch,upstream-commit,fingerprint} "$FILES.new/"
    b2sum kernel/build.sh kernel/profile.sh > "$FILES.new/tools.b2sum"
    pacman -Q clang llvm lld rust > "$FILES.new/compiler"
    replace_dir "$FILES.new" "$FILES"
    # And a record of them in the repo, as a local commit.
    cp "$d"/{PKGBUILD.cachyos,config,PKGBUILD,upstream-commit} "$here/"
    git -C "$here" add PKGBUILD.cachyos config PKGBUILD upstream-commit
    git -C "$here" commit -q -m "Kernel: CachyOS $(get version), commit $(cut -c1-7 "$d/upstream-commit"), reviewed; $mode rebuild" \
        -- PKGBUILD.cachyos config PKGBUILD upstream-commit || true
    mkdir -p "$R/reviewed"; cp "$d"/dl/*.patch "$R/reviewed/" 2>/dev/null || true
    put mode="$mode"
    if [ "$mode" = quick ]; then
        build_stage 3 "$PROFILES/kiln.afdo" "$PROFILES"
        install_stage 3; restart_now 3
    else
        rm -rf "${K:?}"/profile-stage1 "${K:?}"/profile-stage2 "${K:?}"/stage2 "${K:?}"/stage3
        build_stage 1
        install_stage 1; restart_now 1
    fi
}

case ${1:-next} in
status)
    say "Step: $step$( [ "$step" = none ] || printf ', CachyOS %s, %s rebuild, stage %s installed' "$(get version)" "$(get mode)" "$(get installed_stage)")"
    say "Kiln's kernel: $(pacman -Q linux-cachyos-kiln 2>/dev/null || echo none); running $(uname -r)"
    say "Last good: $(ls "$LAST_GOOD" 2>/dev/null | grep -E '^linux-cachyos-kiln-[0-9]' || echo none)"
    # The checks an install relies on, run read-only against what is installed now.
    rel=$(pacman -Q linux-cachyos-kiln | awk '{print $2}')-cachyos-kiln
    boot_files "$rel"
    say "Boot menu and /boot: Kiln's and the rescue kernel's entries and files present; /boot holds the installed Kiln kernel."
    if [ "$(uname -r)" = "$rel" ]; then
        grep -aqF "$(uname -v)" "/usr/lib/modules/$rel/vmlinuz" && say "The running kernel is the installed build." ||
            say "The running kernel is not the installed build (restart pending?)."
    fi ;;
cancel)
    case $step in none|review) ;; *) die "stage $(get installed_stage) is installed; to undo it, run kernel/rebuild.sh back" ;; esac
    rm -f "$STATE"; rm -rf "${R:?}/new"
    say "Rebuild forgotten. Nothing installed was changed." ;;
back)
    pkgs_in "$LAST_GOOD"
    boot_room
    sudo pacman -U --noconfirm "${PKGS[@]}" > "$R/log/back.log" 2>&1 || die "see $R/log/back.log"
    ! grep -E 'ERROR|^error:' "$R/log/back.log" || die "the install reported errors (above; $R/log/back.log)"
    boot_files "$(pacman -Q linux-cachyos-kiln | awk '{print $2}')-cachyos-kiln"
    rm -f "$STATE"
    say "The last good Kiln kernel is back: $(pacman -Q linux-cachyos-kiln). Restart to use it."
    say "kernel/ in the repo still holds the newer, reviewed files; the next check compares with the last good ones." ;;
reviewed) reviewed "${2:-}" ;;
fingerprint) fingerprint "${2:?folder}" ;;
seed)
    # Once, or after a build by hand: record the installed stage 3 kernel, built in
    # $K/stage3 from kernel/ with the profiles in profile-stage1 and -stage2, as the last good one.
    [ "$step" = none ] || die "a rebuild is under way (step: $step)"
    s=$K/stage3
    cmp -s "$s/kiln-autofdo.afdo" "$K/profile-stage1/kiln.afdo" &&
        cmp -s "$s/propeller_cc_profile.txt" "$K/profile-stage2/propeller_cc_profile.txt" &&
        cmp -s "$s/propeller_ld_profile.txt" "$K/profile-stage2/propeller_ld_profile.txt" ||
        die "the profiles in profile-stage1 and -stage2 are not the ones stage 3 was built with"
    cmp -s "$s/config" "$here/config" || die "stage 3 was not built from kernel/config"
    pkgs_in "$s"
    [ "$(pacman -Qip "${PKGS[0]}" | grep '^Build Date')" = "$(pacman -Qi linux-cachyos-kiln | grep '^Build Date')" ] ||
        die "the installed Kiln kernel is not the one in $s"
    d=$(mktemp -d "$R/.seed.XXXX"); trap 'rm -rf "$d"' EXIT
    mkdir "$d/last" "$d/profiles" "$d/reviewed"
    cp "${PKGS[@]}" "$here"/{PKGBUILD.cachyos,PKGBUILD,config,upstream-commit} "$d/last/"
    cp "$s/kiln-autofdo.afdo" "$d/profiles/kiln.afdo"
    cp "$s"/propeller_{cc,ld}_profile.txt "$d/profiles/"
    for f in "$s"/0*.patch; do cp "$f" "$d/reviewed/"; done
    cp "$here/PKGBUILD.cachyos" "$here/config" "$d/"
    b2sum "$s/0001-bore-cachy.patch" | cut -d' ' -f1 > "$d/bore.b2sum"
    fingerprint "$d" > "$d/profiles/fingerprint"
    mkdir -p "$(dirname "$PROFILES")"
    replace_dir "$d/last" "$LAST_GOOD"; replace_dir "$d/profiles" "$PROFILES"; replace_dir "$d/reviewed" "$R/reviewed"
    say "Recorded as the last good kernel: $(basename "${PKGS[0]}")" ;;
next)
    case $step in
    none) check ;;
    review) say "Waiting for review: $(get review)"
            say "After the reviewer: kernel/rebuild.sh reviewed" ;;
    boot1)
        check_boot 1
        if [ "$(get built)" != 2 ]; then
            profile "$K/profile-stage1" 1
            [ -s "$K/profile-stage1/kiln.afdo" ] || die "no AutoFDO profile was made; see the log"
            build_stage 2 "$K/profile-stage1/kiln.afdo"
        fi
        install_stage 2; restart_now 2 ;;
    boot2)
        check_boot 2
        if [ "$(get built)" != 3 ]; then
            [ -x "$PROPELLER_TOOL" ] || die "the Propeller tool is missing: $PROPELLER_TOOL (kernel/README.md)"
            profile "$K/profile-stage2" 2 "$PROPELLER_TOOL"
            [ -s "$K/profile-stage2/propeller_cc_profile.txt" ] && [ -s "$K/profile-stage2/propeller_ld_profile.txt" ] ||
                die "no Propeller profiles were made; see the log"
            # Stage 3 uses the same AutoFDO profile as stage 2, or the Propeller profile would not fit.
            build_stage 3 "$K/profile-stage1/kiln.afdo" "$K/profile-stage2"
        fi
        install_stage 3; restart_now 3 ;;
    boot3)
        check_boot 3
        # Keep what passed: the packages and the files they were made from, and in a full
        # rebuild the profiles that made them. Each swapped in whole.
        pkgs_in "$K/stage3"
        rm -rf "${K:?}/last-good.new"; mkdir "$K/last-good.new"
        cp "${PKGS[@]}" "$FILES"/{PKGBUILD.cachyos,PKGBUILD,config,upstream-commit} "$K/last-good.new/"
        if [ "$(get mode)" = full ]; then
            rm -rf "${PROFILES:?}.new"; mkdir -p "$PROFILES.new"
            cp "$K/profile-stage1/kiln.afdo" "$K/profile-stage2"/propeller_{cc,ld}_profile.txt "$PROFILES.new/"
            cp "$FILES/fingerprint" "$PROFILES.new/"
            replace_dir "$PROFILES.new" "$PROFILES"
        fi
        replace_dir "$K/last-good.new" "$LAST_GOOD"
        rm -f "$STATE"
        say "Kiln's kernel $(pacman -Q linux-cachyos-kiln | awk '{print $2}') is built, running and kept as the last good one."
        say "Next: scripts/measure.sh new, then scripts/measure.sh run, and write the result down." ;;
    *) die "unknown step '$step' in $STATE" ;;
    esac ;;
*) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 64 ;;
esac
