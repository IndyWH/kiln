# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Graphics and image helpers for the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/hyprgraphics"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0/${PV}"
KEYWORDS="amd64"

RDEPEND="
	gnome-base/librsvg:2
	gui-libs/hyprutils:=
	media-libs/libglvnd
	media-libs/libjpeg-turbo:=
	media-libs/libpng:=
	media-libs/libwebp:=
	sys-apps/file
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/pango
	x11-libs/pixman
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

src_configure() {
	local mycmakeargs=( -DBUILD_TESTING=OFF )
	cmake_src_configure
}
