# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration of ccache"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="amd64 ~x86"

RDEPEND="
  dev-util/ccache
"

S="${WORKDIR}"

pkg_preinst() {
  dodir /etc/portage/package.env/overboard
  echo "*/* overboard/ccache" > "${ED}/etc/portage/package.env/overboard/ccache"
  chmod -w "${ED}/etc/portage/package.env/overboard/ccache"

  dodir /etc/portage/env/overboard
  cat > "${ED}/etc/portage/env/overboard/ccache" << EOF
FEATURES="ccache"
CCACHE_DIR="${EPREFIX}/var/tmp/ccache"
EOF
  chmod -w "${ED}/etc/portage/env/overboard/ccache"

  cat > "${ED}/etc/ccache.conf" << EOF
# preserve cache across GCC rebuilds and
# introspect GCC changes through GCC wrapper
compiler_check = %compiler% -v
EOF
}
