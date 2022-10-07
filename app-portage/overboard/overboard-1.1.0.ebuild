# Copyright 1999-2021 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="automatic configuration metapackage"
HOMEPAGE="https://github.com/piedar/overboard"
LICENSE="GPL-2"

SLOT="0"
KEYWORDS="*"
IUSE="ccache"

RDEPEND="
  app-portage/overboard-buildjobs
  ccache? ( app-portage/overboard-ccache )
  app-portage/overboard-cpuflags
"
