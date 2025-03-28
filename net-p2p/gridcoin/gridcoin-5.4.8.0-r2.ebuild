# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake db-use
inherit flag-o-matic systemd xdg-utils

MY_PV="${PV/_p/-hotfix-}"
DESCRIPTION="Proof-of-Stake based cryptocurrency that rewards BOINC computation"
HOMEPAGE="https://gridcoin.us/ https://gridcoin.world/"
SRC_URI="https://github.com/${PN}-community/${PN^}-Research/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN^}-Research-${MY_PV}"

LICENSE="BSD BSD-2 Boost-1.0 MIT SSLeay"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+boinc dbus gui +hardened pie qrcode systemd test upnp"
IUSE+=" +asm cpu_flags_arm_neon cpu_flags_x86_avx2 cpu_flags_x86_sha cpu_flags_x86_sse4_1"
IUSE+=" +system-bdb system-leveldb +system-libsecp256k1 +system-univalue +system-xxd"

# the gui cannot connect to the daemon, so they are mutually exclusive
# https://www.reddit.com/r/gridcoin/comments/9x0zsy/comment/e9r85vf/

REQUIRED_USE="
	dbus? ( gui )
	qrcode? ( gui )
"

RESTRICT="!test? ( test )"

BDB_SLOT="5.3"
COMMON_DEPEND="
	>=dev-libs/boost-1.63.0:=[zlib(+)]
	<dev-libs/boost-1.87.0:=
	>=dev-libs/openssl-1.1:0=
	dev-libs/libzip:=
	net-misc/curl[ssl]
	!gui? (
		acct-group/gridcoin
		acct-user/gridcoin[boinc=]
	)
	gui? (
		dev-qt/qtconcurrent:5
		dev-qt/qtcore:5
		dev-qt/qtgui:5
		dev-qt/qtnetwork:5
		dev-qt/qtwidgets:5
		dbus? ( dev-qt/qtdbus:5 )
		qrcode? ( media-gfx/qrencode )
	)
	system-bdb? ( sys-libs/db:${BDB_SLOT}[cxx] )
	system-leveldb? ( >=dev-libs/leveldb-1.21:= )
	system-libsecp256k1? ( >=dev-libs/libsecp256k1-0.2.0:=[recovery(+)] )
	system-univalue? ( dev-libs/univalue )
	system-xxd? ( test? ( dev-util/xxd ) )
	upnp? ( net-libs/miniupnpc:= )
"

DEPEND="
	${COMMON_DEPEND}
	virtual/pkgconfig
	gui? ( dev-qt/linguist-tools:5 )
	test? ( app-editors/vim-core )
"

RDEPEND="
	${COMMON_DEPEND}
	boinc? ( sci-misc/boinc )
"

IDEPEND="gui? ( dev-util/desktop-file-utils )"

PATCHES=(
)

src_configure() {
	use hardened && append-flags -Wa,--noexecstack

	# copied from https://github.com/gridcoin-community/Gridcoin-Research/blob/6c4598a3ce4aadb13e520298e512cc97709fff51/configure.ac#L651
	# todo: should this be controlled by USE or just *FLAGS instead?
	if use hardened; then
		append-cppflags -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2
		append-flags -fstack-reuse=none -Wstack-protector -fstack-protector-all -fcf-protection=full -fstack-clash-protection
		append-ldflags $(test-flags-CCLD --dynamicbase --nxcompat --high-entropy-va -z,relro -z,now)
	fi

	local mycmakeargs=(
		-DENABLE_DAEMON="$(usex !gui)"
		-DENABLE_GUI="$(usex gui)"
		#-DENABLE_DOCS="$(usex )"
		-DENABLE_TESTS="$(usex test)"
		#-DLUPDATE ? probably not
		#-DSTATIC_LIBS
		#-DSTATIC_RUNTIME

		-DENABLE_SSE41="$(usex cpu_flags_x86_sse4_1)"
		-DENABLE_AVX2="$(usex cpu_flags_x86_avx2)"
		-DENABLE_X86_SHANI="$(usex cpu_flags_x86_sha)"
		-DENABLE_ARM_SHANI="$(usex cpu_flags_arm_neon)"
		-DUSE_ASM="$(usex asm)"

		-DENABLE_PIE="$(usex pie)"
		-DENABLE_QRENCODE="$(usex qrcode)"
		-DENABLE_UPNP="$(usex upnp)"
		#-DDEFAULT_UPNP=
		-DUSE_DBUS="$(usex dbus)"

		-DSYSTEM_BDB="$(usex system-bdb)"
		-DBerkeleyDB_INCLUDE_DIR="$(db_includedir ${BDB_SLOT})"
		-DBerkeleyDB_CXX_LIBRARY="${ESYSROOT}/usr/$(get_libdir)/libdb_cxx-${BDB_SLOT}$(get_libname)"
		-DSYSTEM_LEVELDB="$(usex system-leveldb)"
		-DSYSTEM_SECP256K1="$(usex system-libsecp256k1)"
		-DSYSTEM_UNIVALUE="$(usex system-univalue)"
		-DSYSTEM_XXD="$(usex system-xxd)"
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install
	# todo: consider using this upstream gridcoinresearchd.service
	rm -f "${D}/lib/systemd/system/gridcoinresearchd.service"
	if ! use gui ; then
		newman doc/gridcoinresearchd.1 gridcoinresearchd.1
		newinitd "${FILESDIR}"/gridcoinresearchd.init gridcoinresearchd
		if use systemd ; then
			systemd_dounit "${FILESDIR}"/gridcoinresearchd.service
			if use hardened ; then
				insinto "/usr/lib/systemd/system/gridcoinresearchd.service.d/"
				doins "${FILESDIR}/hardened.conf"
			fi
		fi
		diropts -o${PN} -g${PN}
		keepdir /var/lib/${PN}/.GridcoinResearch/
		newconfd "${FILESDIR}"/gridcoinresearch.conf gridcoinresearch
		fowners gridcoin:gridcoin /etc/conf.d/gridcoinresearch
		dosym ../../../../etc/conf.d/gridcoinresearch /var/lib/${PN}/.GridcoinResearch/gridcoinresearch.conf
	fi
	if use gui ; then
		newbin src/qt/gridcoinresearch gridcoinresearch
		newman doc/gridcoinresearch.1 gridcoinresearch.1
	fi
	dodoc README.md CHANGELOG.md doc/build-unix.md
}

pkg_postinst() {
	# we don't use xdg.eclass because it adds unconditional IDEPENDs
	if use gui; then
		xdg_desktop_database_update
		xdg_icon_cache_update
	fi

	elog "You need to configure this node with a few basic details to do anything"
	elog "useful with gridcoin. The wallet configuration file is located at:"
	! use gui && elog "    /etc/conf.d/gridcoinresearch"
	use gui && elog "    \$HOME/.GridcoinResearch"
	elog "The wiki for this configuration file is located at:"
	elog "    http://wiki.gridcoin.us/Gridcoinresearch_config_file"
}

pkg_postrm() {
	if use gui; then
		xdg_desktop_database_update
		xdg_icon_cache_update
	fi
}
