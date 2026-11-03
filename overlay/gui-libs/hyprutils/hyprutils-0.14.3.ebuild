# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Small C++ library of utilities used across the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/hyprutils"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="amd64"

RDEPEND="x11-libs/pixman"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	local mycmakeargs=( -DBUILD_TESTING=OFF )
	cmake_src_configure
}
