# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Generates C++ code from Wayland protocol files, for the Hyprland projects"
HOMEPAGE="https://github.com/hyprwm/hyprwayland-scanner"
SRC_URI="https://github.com/hyprwm/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="amd64"

RDEPEND="dev-libs/pugixml"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"
