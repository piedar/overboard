# Copyright 1999-2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="automatic configuration for sci-misc/boinc"
GITHUB_REPO="https://github.com/piedar/overboard"
HOMEPAGE="${GITHUB_REPO}"
LICENSE="LGPL-3"

SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="hardened network-retry opencl +rosetta thermal video_cards_intel video_cards_nouveau video_cards_nvidia video_cards_radeonsi"

SRC_URI="
  https://github.com/BOINC/boinc/pull/5504.patch -> boinc-wrapper-sleep-pr5504.patch
"

# rosetta beta has some dynamic link dependencies
RDEPEND="
  sci-misc/boinc[opencl=]
  >=sys-apps/systemd-252
  sys-process/nicest
  opencl? (
    hardened? ( dev-util/clinfo )
    video_cards_intel? ( media-libs/mesa[opencl,video_cards_intel] )
    video_cards_nouveau? ( media-libs/mesa[opencl,video_cards_nouveau] )
    video_cards_nvidia? ( x11-drivers/nvidia-drivers[persistenced(+)] )
    video_cards_radeonsi? ( media-libs/mesa[opencl,video_cards_radeonsi] )
  )
  rosetta? (
    app-arch/brotli
    media-libs/libglvnd[X]
    x11-libs/libxcb
    x11-libs/libXau
    x11-libs/libXdmcp
    x11-libs/libX11
  )
  thermal? ( sys-power/temp-throttle )
"

S="${WORKDIR}"

src_install() {
  default

  insinto "/etc/portage/patches/sci-misc/boinc-wrapper/"
  # https://github.com/BOINC/boinc/pull/5504
  doins "${DISTDIR}/boinc-wrapper-sleep-pr5504.patch"

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

  if use opencl; then
    use video_cards_intel && doins "${FILESDIR}/overboard-opencl-intel.conf"
    use video_cards_nouveau && doins "${FILESDIR}/overboard-opencl-nouveau.conf"
    use video_cards_radeonsi && doins "${FILESDIR}/overboard-opencl-radeonsi.conf"
  fi

  if use thermal; then
    doins "${FILESDIR}/overboard-thermal.conf"
  fi
}
