
# Kiln: checksums for the sources CachyOS's script adds without one, in source order.
# kernel/rebuild.sh fills them in: the NVIDIA module source (checked against NVIDIA's published
# SHA-256) and CachyOS's patches for it; then this machine's profiles, whose sums build.sh
# passes in _kiln_profile_b2sums; then the BORE patch (checked against CachyOS's own sum, in
# linux-cachyos-bore/.SRCINFO at the same commit).
if [ "$_build_nvidia_open" = "yes" ]; then
    b2sums+=(@NVIDIA_SUMS@)
fi
b2sums+=(${_kiln_profile_b2sums:-})
if [ "$_cpusched" = "bore" ]; then
    b2sums+=(@BORE_SUM@)
fi

# Kiln: CachyOS's kernel gives the linker its AutoFDO and Propeller settings only with thin LTO.
# With full LTO the code is generated in the linker as well, so it needs them too.
source+=("kiln-lto-profiles.patch")
b2sums+=('@LTO_SUM@')
