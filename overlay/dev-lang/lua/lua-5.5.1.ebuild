# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="Lua 5.5 library and headers, for building Hyprland"
HOMEPAGE="https://www.lua.org/"
SRC_URI="https://www.lua.org/ftp/${P}.tar.gz"

LICENSE="MIT"
SLOT="5.5"
KEYWORDS="amd64"

src_compile() {
	emake -C src a \
		CC="$(tc-getCC)" \
		AR="$(tc-getAR) rcu" \
		RANLIB="$(tc-getRANLIB)" \
		CFLAGS="${CFLAGS} ${CPPFLAGS} -fPIC -DLUA_USE_LINUX -DLUA_COMPAT_5_4"
}

src_install() {
	insinto "/usr/include/lua${SLOT}"
	doins src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp

	newlib.a src/liblua.a "liblua${SLOT}.a"

	insinto "/usr/$(get_libdir)/pkgconfig"
	newins - "lua${SLOT}.pc" <<-EOF
		Name: Lua
		Description: Lua language library
		Version: ${PV}
		Libs: -L\${EPREFIX}/usr/$(get_libdir) -llua${SLOT} -lm
		Cflags: -I\${EPREFIX}/usr/include/lua${SLOT}
	EOF
	sed -i -e "s:\${EPREFIX}:${EPREFIX}:g" "${ED}/usr/$(get_libdir)/pkgconfig/lua${SLOT}.pc" || die
}
