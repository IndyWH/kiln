# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="A dynamic tiling Wayland compositor"
HOMEPAGE="https://hypr.land/ https://github.com/hyprwm/Hyprland"
SRC_URI="https://github.com/hyprwm/Hyprland/releases/download/v${PV}/source-v${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/hyprland-source"

LICENSE="BSD"
SLOT="0"
KEYWORDS="amd64"

# rtkit needs sdbus-c++, which Gentoo still marks as testing. Left out for now.
# The plugin manager, hyprpm, and the uwsm session are left out too.
RDEPEND="
	dev-lang/lua:5.5
	dev-cpp/muParser
	dev-libs/glib:2
	dev-libs/hyprgraphics:=
	dev-libs/hyprlang:=
	dev-libs/libei
	dev-libs/libinput:=
	dev-libs/re2:=
	dev-libs/udis86
	dev-libs/wayland
	dev-util/glslang:=
	gui-libs/aquamarine:=
	gui-libs/hyprcursor:=
	gui-libs/hyprutils:=
	gui-libs/hyprwire:=
	media-libs/lcms:2
	media-libs/libcanberra
	media-libs/libglvnd
	media-libs/mesa[gbm(+)]
	sys-apps/util-linux
	x11-base/xwayland
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/libXcursor
	x11-libs/libxcb:=
	x11-libs/libxkbcommon
	x11-libs/pango
	x11-libs/pixman
	x11-libs/xcb-util-errors
	x11-libs/xcb-util-wm
"
DEPEND="
	${RDEPEND}
	>=dev-cpp/glaze-7.0.0
	dev-libs/hyprland-protocols
	>=dev-libs/wayland-protocols-1.49
"
BDEPEND="
	dev-util/hyprwayland-scanner
	dev-util/wayland-scanner
	virtual/pkgconfig
"

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTING=OFF
		-DNO_HYPRPM=ON
		-DNO_RTKIT=ON
		-DNO_UWSM=ON
	)
	cmake_src_configure
}
