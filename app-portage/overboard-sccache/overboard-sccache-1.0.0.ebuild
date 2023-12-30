# Copyright 1999-2023 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration of sccache"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
  dev-util/sccache
"

S="${WORKDIR}"

pkg_preinst() {
  keepdir /var/cache/sccache
  fowners root:portage /var/cache/sccache
  fperms 2775 /var/cache/sccache

  dodir /etc/portage/package.env/overboard
  echo "*/* overboard/sccache" > "${ED}/etc/portage/package.env/overboard/sccache"
  chmod -w "${ED}/etc/portage/package.env/overboard/sccache"

  dodir /etc/portage/env/overboard
  cat > "${ED}/etc/portage/env/overboard/sccache" << EOF
RUSTC_WRAPPER="${EPREFIX}/usr/bin/sccache"
SCCACHE_DIR="${EPREFIX}/var/cache/sccache"
SCCACHE_MAX_FRAME_LENGTH=104857600
CARGO_INCREMENTAL=0
EOF
  chmod -w "${ED}/etc/portage/env/overboard/sccache"
}
