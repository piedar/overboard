# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: toolchain-override.eclass
# @MAINTAINER:
# Benn Snyder <benn.snyder@gmail.com>
# @AUTHOR:
# Benn Snyder <benn.snyder@gmail.com>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: Override compiler toolchain
# @DESCRIPTION:
# The toolchain-override.eclass provides functions to change the
# active compiler toolchain based on USE flags or other conditions.
#
# @CODE
# inherit toolchain-override
#
# src_configure() {
# 	use clang && tc-use-clang
#   # verify compiler available if USE="-clang" CC="clang"
# 	! use clang && tc-is-clang && require_version -b "sys-devel/clang"
# }
# @CODE

inherit flag-o-matic toolchain-funcs

case ${EAPI} in
	7|8) ;;
	*) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

if [[ ! ${_TOOLCHAIN_OVERRIDE_ECLASS} ]]; then
_TOOLCHAIN_OVERRIDE_ECLASS=1

# FUNCTION: require_version
# @USAGE: [-r|-d|-b] <package>
# @DESCRIPTION:
# Kills the build if the specified package is not installed.
# Accepts the same arguments as has_version.
require_version() {
	has_version "${@}" || die "${@: -1} is required but not installed"
}

# @FUNCTION: tc-use-gcc
# @USAGE:
# @DESCRIPTION:
# Switch the toolchain to gcc and strip unsupported flags if necessary.
tc-use-gcc() {
	tc-is-gcc && return

	einfo "Overriding toolchain to use gcc"

	AR=gcc-ar
	CC=${CHOST}-gcc
	CXX=${CHOST}-g++
	NM=gcc-nm
	RANLIB=gcc-ranlib

	strip-unsupported-flags
}

# @FUNCTION: tc-use-clang
# @USAGE:
# @DESCRIPTION:
# Switch the toolchain to clang and strip unsupported flags if necessary.
tc-use-clang() {
	tc-is-clang && return

	einfo "Overriding toolchain to use clang"

	# todo: is this versioning necessary?
	#local version_clang=$(clang --version 2>/dev/null | grep -F -- 'clang version' | awk '{ print $3 }')
	#[[ -n ${version_clang} ]] && version_clang=$(ver_cut 1 "${version_clang}")
	#[[ -z ${version_clang} ]] && die "Failed to read clang version!"
	#CC=${CHOST}-clang-${version_clang}
	#CXX=${CHOST}-clang++-${version_clang}

	AR=llvm-ar
	CC=${CHOST}-clang
	CXX=${CHOST}-clang++
	NM=llvm-nm
	RANLIB=llvm-ranlib

	strip-unsupported-flags
}

fi
