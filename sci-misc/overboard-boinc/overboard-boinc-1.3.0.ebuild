# Copyright 1999-2023 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="automatic configuration for sci-misc/boinc"
GITHUB_REPO="https://github.com/piedar/overboard"
HOMEPAGE="${GITHUB_REPO}"
LICENSE="LGPL-3"

SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="hardened network-retry opencl thermal video_cards_radeonsi"

RDEPEND="
  sci-misc/boinc[opencl=]
  >=sys-apps/systemd-252
  sys-process/nicest
  hardened? ( opencl? ( dev-util/clinfo ) )
  opencl? (
    hardened? ( dev-util/clinfo )
    video_cards_radeonsi? ( media-libs/mesa[opencl,video_cards_radeonsi] )
  )
  thermal? ( sys-power/temp-throttle )
"

S="${WORKDIR}"

src_install() {
  default

  systemd_dounit "${FILESDIR}/boinc-client-network-retry.service"
  if use network-retry; then
    systemd_enable_service "boinc-client.service" "boinc-client-network-retry.service"
  fi

  insinto "/lib/systemd/system/boinc-client.service.d/"

  doins "${FILESDIR}/overboard-reload.conf"
  doins "${FILESDIR}/overboard-nicest.conf"

  if use hardened; then
    doins "${FILESDIR}/overboard-hardened.conf"
    if use opencl; then
      doins "${FILESDIR}/overboard-hardened-opencl.conf"
    fi
  fi

  if use opencl && use video_cards_radeonsi; then
    doins "${FILESDIR}/overboard-opencl-radeonsi.conf"
  fi

  if use thermal; then
    doins "${FILESDIR}/overboard-thermal.conf"
  fi
}
