# Copyright 1999-2022 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="automatic configuration for linux kernel"
GITHUB_REPO="https://github.com/piedar/overboard"
HOMEPAGE="${GITHUB_REPO}"
LICENSE="LGPL-3"

SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="btrfs reiserfs"

S="${WORKDIR}"

_yesno() {
  use "${1:?no flag specified}" && echo "yes" || echo "no"
}

src_install() {
  default

  insinto "/etc/kernel/config.d/"
  insopts --mode=444
  doins "${FILESDIR}/00-overboard-devices-io-obscure-no.config"
  doins "${FILESDIR}/00-overboard-devices-network-obscure-no.config"
  doins "${FILESDIR}/00-overboard-filesystems-obscure-no.config"
  doins "${FILESDIR}/00-overboard-filesystems-btrfs-$(_yesno btrfs).config"
  doins "${FILESDIR}/00-overboard-filesystems-reiserfs-$(_yesno reiserfs).config"
  doins "${FILESDIR}/00-overboard-partitions-obscure-no.config"
}
