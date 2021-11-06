# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration of CPU_FLAGS_X86"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="amd64 ~x86"

RDEPEND="
  app-portage/cpuid2cpuflags:=
  sys-apps/sed
"

S="${WORKDIR}"

pkg_preinst() {
  dodir /etc/portage/package.env/overboard
  echo "*/* overboard/cpuflags" > "${ED}/etc/portage/package.env/overboard/cpuflags"
  chmod -w "${ED}/etc/portage/package.env/overboard/cpuflags"

  dodir /etc/portage/env/overboard
  echo "CPU_FLAGS_X86=\"$(cpuid2cpuflags | sed 's/CPU_FLAGS_X86: //')\"" > "${ED}/etc/portage/env/overboard/cpuflags"
  chmod -w "${ED}/etc/portage/env/overboard/cpuflags"
}
