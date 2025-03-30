# Copyright 2025 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Keeps CPU temperature under control"
GITHUB_REPO="https://github.com/piedar/${PN}"
HOMEPAGE="${GITHUB_REPO}"
SRC_URI="${GITHUB_REPO}/archive/${PV}.tar.gz -> ${P}.tar.gz"
LICENSE="AGPL-3"

SLOT="0"
KEYWORDS="amd64"

RDEPEND="
  =dev-lang/python-3*
"

src_install() {
  dobin "tempit"
  systemd_dounit "lib/systemd/system/tempit.service"
}
