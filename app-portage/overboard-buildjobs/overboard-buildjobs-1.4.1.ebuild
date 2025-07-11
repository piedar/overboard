# Copyright 1999-2024 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration of parallel build jobs"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="nicest"

BDEPEND="
  dev-lang/python
"
RDEPEND="
  nicest? ( sys-process/nicest )
  !nicest? ( sys-apps/util-linux )
"

S="${WORKDIR}"

generate_config() {
  python << EOF
import math, os
numcpu = max(1, len(os.sched_getaffinity(0)) if 'sched_getaffinity' in dir(os) else os.cpu_count())
config = f"--jobs={math.ceil(1.1 * numcpu)} --load-average={math.ceil(4.00 * numcpu)}"
print(f"MAKEOPTS=\"\${{MAKEOPTS}} {config}\"")
print(f"EMERGE_DEFAULT_OPTS=\"\${{EMERGE_DEFAULT_OPTS}} {config} --keep-going\"")
EOF

  if use nicest; then
    cat <<EOF
PORTAGE_IONICE_COMMAND="renicest \\\${PID}"
EOF
  else
    cat <<EOF
PORTAGE_NICENESS="19"
PORTAGE_SCHEDULING_POLICY="batch"
PORTAGE_IONICE_COMMAND="ionice --class idle --pid \\\${PID}"
EOF
  fi
}

pkg_preinst() {
  dodir /etc/portage/package.env/overboard
  echo "*/* overboard/buildjobs" > "${ED}/etc/portage/package.env/overboard/buildjobs"
  chmod -w "${ED}/etc/portage/package.env/overboard/buildjobs"

  dodir /etc/portage/env/overboard
  generate_config > "${ED}/etc/portage/env/overboard/buildjobs"
  chmod -w "${ED}/etc/portage/env/overboard/buildjobs"
}
