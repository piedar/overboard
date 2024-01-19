# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Gathers and converts sampled performance data"
GITHUB_REPO="https://github.com/piedar/${PN}"
HOMEPAGE="${GITHUB_REPO}"
SRC_URI="${GITHUB_REPO}/archive/${PV}.tar.gz -> ${P}.tar.gz"
LICENSE="AGPL-3"

SLOT="0"
KEYWORDS="amd64"

# gcc not supported because autofdo is a mess compared to llvm-profgen
# todo: find a way to make it work with gcc

RDEPEND="
  app-alternatives/awk
  app-shells/bash
  dev-util/perf
  sys-apps/coreutils
  sys-apps/findutils
  sys-devel/llvm
"

# todo: detect and ewarn about unsupported CPUs

src_install() {
  dobin "perf2prof"
  dobin "perfdata"
  dobin "perfdata-cleanup"
  dobin "perfdata-mkprof"
}
