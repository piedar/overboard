# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="automatic configuration for sci-misc/boinc"
GITHUB_REPO="https://github.com/piedar/overboard"
HOMEPAGE="${GITHUB_REPO}"
LICENSE="LGPL-3"

SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="hardened opencl thermal"

RDEPEND="
  sci-misc/boinc[opencl=]
  sys-process/nicest
  hardened? ( opencl? ( dev-util/clinfo ) )
  thermal? ( sys-power/temp-throttle )
"

S="${WORKDIR}"

src_install() {
  default

  insinto "/lib/systemd/system/boinc-client.service.d/"
  
  doins "${FILESDIR}/overboard-reload.conf"
  doins "${FILESDIR}/overboard-nicest.conf"
  
  if use hardened; then
    doins "${FILESDIR}/overboard-hardened.conf"
    if use opencl; then
      doins "${FILESDIR}/overboard-hardened-opencl.conf"
    fi
  fi

  if use thermal; then
    doins "${FILESDIR}/overboard-thermal.conf"
  fi
}
