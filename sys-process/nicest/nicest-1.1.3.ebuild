# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Runs processes at lowest possible priority"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="LGPL-3"

SLOT="0"
KEYWORDS="*"

RDEPEND="
  sys-apps/coreutils
  sys-apps/util-linux
"

S="${WORKDIR}"

src_install() {
  dobin "${FILESDIR}/nicest"
  dobin "${FILESDIR}/renicest"

  # systemd support will be detected at runtime
  insinto /lib/systemd/system/
  doins "${FILESDIR}/nicest.slice"
  insinto /usr/share/polkit-1/rules.d/
  doins "${FILESDIR}/99-nicest.rules"
}

pkg_postinst() {
  if [ "$(cat /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null)" = "1" ] ; then
    ewarn "This system has autogroup enabled, so it may not respect NICE values or CPU scheduling classes."
    ewarn "Try setting kernel.sched_autogroup_disabled = 1 in /etc/sysctl.conf or passing noautogroup when booting the kernel."
  fi
}
