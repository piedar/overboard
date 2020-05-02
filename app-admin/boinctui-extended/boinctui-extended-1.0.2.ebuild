# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit autotools

DESCRIPTION="a curses-based terminal BOINC client manager"
GITHUB_REPO="https://github.com/mpentler/boinctui-extended"
HOMEPAGE="${GITHUB_REPO}"

SRC_URI="${GITHUB_REPO}/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

IUSE=""

COMMON_DEPEND="
	dev-libs/openssl
	dev-libs/expat
	sys-libs/ncurses
"
BDEPEND="sys-devel/autoconf"
DEPEND="${COMMON_DEPEND}"
RDEPEND="${COMMON_DEPEND}"

src_prepare() {
  default
  eautoconf
}

src_configure() {
  default

  # add missing -ltinfow to linker options
  sed -i -e 's/^\(LIBS\s*=.*\)/\1 -ltinfow/' Makefile
}
