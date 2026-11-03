# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="The fast messaging library of the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/hyprwire"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="amd64"

RDEPEND="
	dev-libs/libffi:=
	dev-libs/pugixml
	gui-libs/hyprutils:=
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	local mycmakeargs=( -DBUILD_TESTING=OFF )
	cmake_src_configure
}
