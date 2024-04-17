# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake
inherit flag-o-matic systemd desktop

DESCRIPTION="Gridcoin Proof-of-Stake based crypto-currency that rewards BOINC computation"
HOMEPAGE="https://gridcoin.us/"
GH_REPO="https://github.com/${PN}-community/${PN^}-Research"
SRC_URI="${GH_REPO}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
# todo: arm
KEYWORDS="~amd64"

IUSE="+boinc daemon dbus +hardened pie qrcode qt5 systemd test upnp utils"
IUSE+=" +asm cpu_flags_x86_avx2 cpu_flags_x86_sha cpu_flags_x86_sse4_1"
IUSE+=" +system-bdb +system-libsecp256k1 system-univalue +system-xxd"

# Note: The client *CAN* *NOT* connect to the daemon like the BOINc client does.
#       Therefore either run the daemon or the gui client. Furthermore starting the gui client while
#       the daemon is running will kill the latter.
#  See: https://www.reddit.com/r/gridcoin/comments/9x0zsy/comment/e9r85vf/
#       "The GUI instance will not rpc to another wallet process."
REQUIRED_USE="
	^^ ( daemon qt5 )
"

RESTRICT="!test? ( test )"

COMMON_DEPEND="
	>=dev-libs/libevent-2.1.12
	>=dev-libs/boost-1.63.0:0=
	>=dev-libs/openssl-1.1:0=
	dev-libs/libzip
	net-misc/curl[ssl]
	daemon? (
		acct-group/gridcoin
		acct-user/gridcoin[boinc=]
	)
	qt5? (
		dev-qt/qtcore:5 dev-qt/qtgui:5 dev-qt/qtnetwork:5 dev-qt/qtwidgets:5 dev-qt/qtconcurrent:5 dev-qt/linguist:5
		dbus? ( dev-qt/qtdbus:5 )
		qrcode? ( media-gfx/qrencode )
	)
	system-bdb? ( sys-libs/db:5.3[cxx] )
	system-libsecp256k1? ( >=dev-libs/libsecp256k1-0.2.0 )
	system-univalue? ( dev-libs/univalue )
	system-xxd? ( test? ( dev-util/xxd ) )
	upnp? ( >=net-libs/miniupnpc-1.9.0 )
	utils? ( net-p2p/bitcoin-cli dev-util/bitcoin-tx )
"

DEPEND="
	${COMMON_DEPEND}
	qt5? ( dev-qt/linguist-tools:5 )
"

RDEPEND="
	${COMMON_DEPEND}
	boinc? ( sci-misc/boinc )
"

S="${WORKDIR}/${PN^}-Research-${PV}"
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
		-DENABLE_DAEMON="$(usex daemon)"
		-DENABLE_GUI="$(usex qt5)"
		#-DENABLE_DOCS="$(usex )"
		-DENABLE_TESTS="$(usex test)"
		#-DLUPDATE ? probably not
		#-DSTATIC_LIBS
		#-DSTATIC_RUNTIME

		-DENABLE_SSE41="$(usex cpu_flags_x86_sse4_1)"
		-DENABLE_AVX2="$(usex cpu_flags_x86_avx2)"
		-DENABLE_X86_SHANI="$(usex cpu_flags_x86_sha)"
		#-DENABLE_ARM_SHANI="$(usex )"
		-DUSE_ASM="$(usex asm)"

		-DENABLE_PIE="$(usex pie)"
		-DENABLE_QRENCODE="$(usex qrcode)"
		-DENABLE_UPNP="$(usex upnp)"
		#-DDEFAULT_UPNP=
		-DUSE_DBUS="$(usex dbus)"

		-DSYSTEM_BDB="$(usex system-bdb)"
		#-DSYSTEM_LEVELDB="$(usex system-leveldb)"
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
	if use daemon ; then
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
	if use qt5 ; then
		newbin src/qt/gridcoinresearch gridcoinresearch
		newman doc/gridcoinresearch.1 gridcoinresearch.1
		domenu contrib/gridcoinresearch.desktop
		for size in 16 22 24 32 48 64 128 256 ; do
			doicon -s "${size}" "share/icons/hicolor/${size}x${size}/apps/gridcoinresearch.png"
		done
		doicon -s scalable "share/icons/hicolor/scalable/apps/gridcoinresearch.svg"
	fi
	dodoc README.md CHANGELOG.md doc/build-unix.md
}

pkg_postinst() {
	elog
	elog "You are using a source compiled version of gridcoin."
	use daemon && elog "The daemon can be found at /usr/bin/gridcoinresearchd"
	use qt5 && elog "The graphical wallet can be found at /usr/bin/gridcoinresearch"
	use dbus && ! use qt5 && elog "USE=dbus ignored due to USE=-qt5"
	use qrcode && ! use qt5 && elog "USE=qrcode ignored due to USE=-qt5"
	elog
	elog "You need to configure this node with a few basic details to do anything"
	elog "useful with gridcoin. The wallet configuration file is located at:"
	use daemon && elog "    /etc/conf.d/gridcoinresearch"
	use qt5 && elog "    \$HOME/.GridcoinResearch"
	elog "The wiki for this configuration file is located at:"
	elog "    http://wiki.gridcoin.us/Gridcoinresearch_config_file"
	elog
}
