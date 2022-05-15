# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Throttles system CPU frequency based on a desired maximum temperature"
GITHUB_REPO="https://github.com/Sepero/temp-throttle"
HOMEPAGE="${GITHUB_REPO}"
LICENSE="GPL-2"

COMMIT="4e6fa06ea036129c4a815fc5d4494556578624e1"
SRC_URI="${GITHUB_REPO}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"

SLOT="0"
KEYWORDS="amd64 ~x86"

RDEPEND="
  sys-apps/coreutils
  sys-apps/findutils
"

S="${WORKDIR}/${PN}-${COMMIT}"

src_install() {
  default
  dodoc README.md
  newbin temp_throttle.sh temp-throttle

  insinto /lib/systemd/system/
  doins "${FILESDIR}/temp-throttle.service"
}
