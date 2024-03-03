# Copyright 2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic systemd desktop

DESCRIPTION="Gridcoin Proof-of-Stake based crypto-currency that rewards BOINC computation"
HOMEPAGE="https://gridcoin.us/"
GH_REPO="https://github.com/${PN}-community/${PN^}-Research"
SRC_URI="${GH_REPO}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="+bench +boinc +ccache daemon dbus debug +hardened +libraries pic qrcode qt5 static +system-bdb systemd test upnp utils"

# Note: The client *CAN* *NOT* connect to the daemon like the BOINc client does.
#       Therefore either run the daemon or the gui client. Furthermore starting the gui client while
#       the daemon is running will kill the latter.
#  See: https://www.reddit.com/r/gridcoin/comments/9x0zsy/comment/e9r85vf/
#       "The GUI instance will not rpc to another wallet process."
REQUIRED_USE="
	^^ ( daemon qt5 )
"

RESTRICT="!test? ( test )"

RDEPEND="
	>=dev-libs/libevent-2.1.12
	>=dev-libs/boost-1.60.0:0=
	>=dev-libs/openssl-1.1:0=
	dev-libs/libzip
	system-bdb? ( sys-libs/db:5.3[cxx] )
	boinc? ( sci-misc/boinc )
	daemon? (
		acct-group/gridcoin
		acct-user/gridcoin[boinc=]
	)
	qt5? (
		dev-qt/qtcore:5 dev-qt/qtgui:5 dev-qt/qtnetwork:5 dev-qt/qtwidgets:5 dev-qt/qtconcurrent:5 dev-qt/qtcharts:5
		dbus? ( dev-qt/qtdbus:5 )
		qrcode? ( media-gfx/qrencode )
	)
	upnp? ( net-libs/miniupnpc )
	utils? ( net-p2p/bitcoin-cli dev-util/bitcoin-tx )
"
DEPEND="
	${RDEPEND}
	qt5? ( dev-qt/linguist-tools:5 )
"

S="${WORKDIR}/${PN^}-Research-${PV}"
PATCHES=(
)

# todo: build with new cmake system, which allows for more system libs

pkg_setup() {
	if use system-bdb; then
		BDB_VER="$(best_version sys-libs/db:5.3)"
		export BDB_CFLAGS="-I/usr/include/db${BDB_VER:12:3}"
		export BDB_LIBS="-ldb_cxx-${BDB_VER:12:3}"
	fi
}

src_prepare() {
	if use debug && [[ ! $(portageq envvar FEATURES) =~ .*(splitdebug|nostrip).* ]]; then
		ewarn "You have enabled debug flags and macros during compilation."
		ewarn "For these to be useful, you should also have Portage retain debug symbols."
		ewarn "See https://wiki.gentoo.org/wiki/Debugging on configuring your environment"
		ewarn "and set your desired FEATURES before (re-)building this package."
	fi
	default
	./autogen.sh
}

src_configure() {
	use hardened && append-flags -Wa,--noexecstack
	econf \
		$(use_enable bench)            \
		$(use_enable ccache)           \
		$(use_enable debug)            \
		$(use_enable hardened hardening) \
		$(use_enable static)           \
		$(use_enable test tests)       \
		$(use_enable !system-bdb embedded-bdb) \
		$(use_with daemon)             \
		$(use_with dbus qtdbus)        \
		$(use_with libraries libs)     \
		$(use_with pic)                \
		$(use_with qrcode qrencode)    \
		$(use_with qt5 gui qt5)        \
		$(use_with upnp miniupnpc)     \
		$(use_with utils)
}

src_install() {
	if use daemon ; then
		newbin src/gridcoinresearchd gridcoinresearchd
		newman doc/gridcoinresearchd.1 gridcoinresearchd.1
		newinitd "${FILESDIR}"/gridcoinresearchd.init gridcoinresearchd
		if use systemd ; then
			systemd_dounit "${FILESDIR}"/gridcoinresearchd.service
			if use hardened ; then
				insinto "/lib/systemd/system/gridcoinresearchd.service.d/"
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
