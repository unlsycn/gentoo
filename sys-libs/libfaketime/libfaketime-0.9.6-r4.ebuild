# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"

inherit flag-o-matic toolchain-funcs multilib-minimal

DESCRIPTION="Report faked system time to programs"
HOMEPAGE="http://www.code-wizards.com/projects/libfaketime/ https://github.com/wolfcw/libfaketime"
SRC_URI="https://github.com/wolfcw/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ~ppc ~ppc64 -riscv sparc x86"

PATCHES=( "${FILESDIR}"/${PN}-0.9.8-Treat-unknown-clock_ids-like-CLOCK_REALTIME.patch )

src_prepare() {
	default

	sed -i 's/-Werror //' "${S}/src/Makefile" || die

	sed -i 's/-Werror //' "${S}/test/Makefile" || die

	# Bug #617624 (GCC-6 compatibility)
	sed -i 's/-Wno-nonnull-compare //' "${S}/src/Makefile" || die

	multilib_copy_sources
}

multilib_src_compile() {
	local target=all

	pushd src > /dev/null || die
	multilib_is_native_abi || target="${PN}.so.1 ${PN}MT.so.1"
	# ${target} is intentionally not quoted
	emake CC="$(tc-getCC)" LIBDIRNAME="/$(get_libdir)" PREFIX=/usr ${target}
	popd > /dev/null || die
}

multilib_src_test() {
	multilib_is_native_abi && emake CC="$(tc-getCC)" test
}

multilib_src_install() {
	multilib_is_native_abi && dobin src/faketime
	exeinto /usr/$(get_libdir)
	doexe src/${PN}*.so.*
	dosym ${PN}.so.1 /usr/$(get_libdir)/${PN}.so
	dosym ${PN}MT.so.1 /usr/$(get_libdir)/${PN}MT.so
}

multilib_src_install_all() {
	doman man/faketime.1
	dodoc NEWS README TODO
}
