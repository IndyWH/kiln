# Copyright 2026 Kiln Linux authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..14} )
inherit cmake python-any-r1

DESCRIPTION="LLVM's post-link optimiser, for Kiln's Rust recipe. Gentoo has no package for it"
HOMEPAGE="https://github.com/llvm/llvm-project/tree/main/bolt"
SRC_URI="https://github.com/llvm/llvm-project/releases/download/llvmorg-${PV}/llvm-project-${PV}.src.tar.xz"
S="${WORKDIR}/llvm-project-${PV}.src"
CMAKE_USE_DIR="${S}/llvm"
CMAKE_BUILD_TYPE=Release

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="amd64"
RESTRICT="test"

RDEPEND="virtual/zlib:="
DEPEND="${RDEPEND}"
BDEPEND="${PYTHON_DEPS}"

src_configure() {
	local mycmakeargs=(
		# One self-contained program: cmake.eclass would otherwise split it into shared libraries.
		-DBUILD_SHARED_LIBS=OFF
		-DLLVM_ENABLE_PROJECTS=bolt
		-DLLVM_TARGETS_TO_BUILD=X86
		-DLLVM_ENABLE_ASSERTIONS=OFF
		-DLLVM_ENABLE_ZLIB=ON
		-DLLVM_ENABLE_ZSTD=OFF
		-DLLVM_ENABLE_LIBXML2=OFF
		-DLLVM_ENABLE_BINDINGS=OFF
		-DLLVM_INCLUDE_TESTS=OFF
		-DLLVM_INCLUDE_BENCHMARKS=OFF
		-DLLVM_INCLUDE_EXAMPLES=OFF
		-DLLVM_INCLUDE_DOCS=OFF
		-DLLVM_LIBDIR_SUFFIX=
	)
	cmake_src_configure
}

src_compile() {
	cmake_src_compile llvm-bolt merge-fdata bolt_rt
}

src_install() {
	"${BUILD_DIR}"/bin/llvm-bolt --version || die "llvm-bolt does not run"
	# Its own folder: BOLT looks for its runtime in ../lib, beside the program.
	exeinto /usr/lib/kiln-bolt/bin
	doexe "${BUILD_DIR}"/bin/llvm-bolt "${BUILD_DIR}"/bin/merge-fdata
	insinto /usr/lib/kiln-bolt/lib
	doins "${BUILD_DIR}"/lib/libbolt_rt_instr.a
}
