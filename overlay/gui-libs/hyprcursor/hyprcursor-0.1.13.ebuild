# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="The cursor theme format and library of the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/hyprcursor"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="amd64"

RDEPEND="
	dev-cpp/tomlplusplus
	dev-libs/hyprlang:=
	dev-libs/libzip:=
	gnome-base/librsvg:2
	x11-libs/cairo
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	local mycmakeargs=( -DBUILD_TESTING=OFF )
	cmake_src_configure
}
