# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration of parallel build jobs"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="amd64 ~x86"

RDEPEND="
  dev-lang/python
  sys-apps/util-linux
"

S="${WORKDIR}"

generate_config() {
  python << EOF
import math, os
numcpu = max(1, len(os.sched_getaffinity(0)) if 'sched_getaffinity' in dir(os) else os.cpu_count())
config = f"--jobs={math.ceil(1.5 * numcpu)} --load-average={math.ceil(2 * numcpu)}"
print(f"MAKEOPTS=\"{config}\"")
print(f"EMERGE_DEFAULT_OPTS=\"{config} --keep-going\"")
print("PORTAGE_NICENESS=\"18\"")
print("PORTAGE_IONICE_COMMAND=\"ionice -c 3 -p \\\${PID}\"")
EOF
}

pkg_preinst() {
  dodir /etc/portage/package.env/overboard
  echo "*/* overboard/buildjobs" > "${ED}/etc/portage/package.env/overboard/buildjobs"
  chmod -w "${ED}/etc/portage/package.env/overboard/buildjobs"

  dodir /etc/portage/env/overboard
  generate_config > "${ED}/etc/portage/env/overboard/buildjobs"
  chmod -w "${ED}/etc/portage/env/overboard/buildjobs"
}

pkg_postinst() {
  if [ "$(cat /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null)" = "1" ] ; then
    ewarn "This system has autogroup enabled, so it may not respect NICE values or CPU scheduling classes."
    ewarn "Try setting kernel.sched_autogroup_disabled = 1 in /etc/sysctl.conf or passing noautogroup when booting the kernel."
  fi
}