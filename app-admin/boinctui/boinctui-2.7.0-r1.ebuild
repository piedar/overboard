# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="a curses-based terminal BOINC client manager"
GITHUB_REPO="https://github.com/suleman1971/boinctui"
HOMEPAGE="${GITHUB_REPO}"

COMMIT="35d0ddc601df12b09632c5cd7bf31c8b8db6649f"
SRC_URI="${GITHUB_REPO}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${COMMIT}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+gnutls"

COMMON_DEPEND="
	gnutls? ( net-libs/gnutls )
  !gnutls? ( dev-libs/openssl )
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
  econf \
		$(use_with gnutls)

  # add missing -ltinfow to linker options
  sed -i -e 's/^\(LIBS\s*=.*\)/\1 -ltinfow/' Makefile
}
