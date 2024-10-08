# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DIST_AUTHOR=ADAMK
DIST_VERSION=1.08
inherit perl-module

DESCRIPTION="Does your process have access to the web"

SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ppc ppc64 ~riscv sparc x86 ~amd64-linux ~x86-linux"

# https://rt.cpan.org/Public/Bug/Display.html?id=112728
PATCHES=("${FILESDIR}/${DIST_VERSION}-no-network.patch")

RDEPEND="
	>=dev-perl/libwww-perl-5.805.0
	>=dev-perl/URI-1.350.0
"
BDEPEND="${RDEPEND}
	>=virtual/perl-ExtUtils-MakeMaker-6.420.0
	test? ( >=virtual/perl-Test-Simple-0.420.0 )
"

src_prepare() {
	sed -i -e 's/use inc::Module::Install::DSL 1\.01;/use lib q[.];\nuse inc::Module::Install::DSL 1.01;/' Makefile.PL ||
		die "Can't patch Makefile.PL for 5.26 dot-in-inc"
	perl-module_src_prepare
}
