# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="a curses-based terminal BOINC client manager"
GITHUB_REPO="https://github.com/suleman1971/boinctui"
HOMEPAGE="${GITHUB_REPO}"

COMMIT="6656f288580170121f53d0e68c35077f5daa700b"
SRC_URI="${GITHUB_REPO}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${COMMIT}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+gnutls"

COMMON_DEPEND="
  gnutls? ( net-libs/gnutls )
  !gnutls? ( dev-libs/openssl:0= )
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
    $(use gnutls || echo '--without-gnutls') # --with-gnutls does not work correctly

  # add missing -ltinfow to linker options
  sed -i -e 's/^\(LIBS\s*=.*\)/\1 -ltinfow/' Makefile
}
