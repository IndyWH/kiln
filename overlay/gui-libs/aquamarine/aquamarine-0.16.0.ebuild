# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="The screen and input library of the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/aquamarine"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="amd64"

RDEPEND="
	dev-libs/libinput:=
	dev-libs/wayland
	gui-libs/hyprutils:=
	media-libs/libdisplay-info:=
	media-libs/libglvnd
	media-libs/mesa[gbm(+)]
	sys-apps/hwdata
	sys-auth/seatd:=
	virtual/libudev:=
	x11-libs/libdrm
	x11-libs/pixman
"
DEPEND="
	${RDEPEND}
	dev-libs/wayland-protocols
"
BDEPEND="
	dev-util/hyprwayland-scanner
	dev-util/wayland-scanner
	virtual/pkgconfig
"

src_configure() {
	local mycmakeargs=( -DBUILD_TESTING=OFF )
	cmake_src_configure
}
