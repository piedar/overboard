# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..11} )
BOINC_APP_OPTIONAL="true"
inherit boinc-app flag-o-matic meson optfeature python-any-r1 toolchain-funcs toolchain-override

DESCRIPTION="Program for docking ligands to proteins and nucleic acids"
HOMEPAGE="https://gitlab.com/Jukic/cmdock"
SRC_URI="https://gitlab.com/Jukic/${PN}/-/archive/v${PV}/${PN}-v${PV}.tar.bz2"
S="${WORKDIR}/${PN}-v${PV}"

LICENSE="LGPL-3 ZLIB"
SLOT="0/${PV}"
KEYWORDS="~amd64"
# todo: make openmp optional
IUSE="apidoc boinc clang cpu_flags_x86_sse2 doc perfdata-gen perfdata-use pgo test"
REQUIRED_USE="perfdata-use? ( clang )"
RESTRICT="perfdata-gen? ( strip ) !test? ( test )"

RDEPEND="
	boinc? ( sci-misc/boinc-wrapper )
	perfdata-gen? (
		app-alternatives/sh
		>=dev-util/perfdata-0.3.1
	)
"
DEPEND="
	dev-cpp/eigen:3
	>=dev-cpp/indicators-2.3-r1
	>=dev-cpp/pcg-cpp-0.98.1_p20210406-r1
	=dev-libs/cxxopts-3.0*
	perfdata-use? (
		sci-biology/cmdock[boinc?,perfdata-gen]
	)
"
BDEPEND_CLANG="sys-devel/clang"
BDEPEND_CLANG_PGO="
	sys-devel/llvm
	sys-libs/compiler-rt-sanitizers[profile]
"
BDEPEND="
	apidoc? (
		app-doc/doxygen
		dev-texlive/texlive-fontutils
	)
	clang? (
		${BDEPEND_CLANG}
		pgo? ( ${BDEPEND_CLANG_PGO} )
	)
	perfdata-use? (
		dev-util/perfdata
		boinc? (
			acct-user/boinc
			sys-apps/coreutils
			sys-apps/util-linux
		)
	)
	doc? (
		$(python_gen_any_dep '
			dev-python/insipid-sphinx-theme[${PYTHON_USEDEP}]
			dev-python/sphinx[${PYTHON_USEDEP}]
		')
	)
	pgo? (
		sys-apps/coreutils
	)
	test? ( ${PYTHON_DEPS} )
"

# todo: fix upstream
PATCHES=(
	"${FILESDIR}/${PN}-0.2.0-streampos-type.patch"
	"${FILESDIR}/${PN}-0.2.0-remove-shadowed-variable.patch"
)

DOCS=( README.md changelog.md )

BOINC_MASTER_URL="https://www.sidock.si/sidock/"
BOINC_INVITATION_CODE="Crunch_4Science"
BOINC_APP_HELPTEXT=\
"The easiest way to do something useful with this application
is to attach it to SiDock@home BOINC project."

readonly INSTALL_PREFIX="${EPREFIX}/opt/${P}"
readonly CMDOCK_EXE="${INSTALL_PREFIX}/bin/cmdock"
: "${PERFDATA_PROFILE_DIR_BOINC:=${EPREFIX%/}$(get_boincdir)/.cache/perfdata/cmdock}"

python_check_deps() {
	use doc || return 0

	python_has_version "dev-python/sphinx[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/insipid-sphinx-theme[${PYTHON_USEDEP}]"
}

foreach_wrapper_job() {
	sed -e "s:@PREFIX@:${INSTALL_PREFIX}:g" -i "${1}" || die
}

pkg_setup() {
	python-any-r1_pkg_setup

	if use boinc && use perfdata-use && [ "${MERGE_TYPE}" != 'binary' ] && [ -z "${PERFDATA_PROFILE}" ]; then
		# collect perfdata created by cmdock running under boinc
		# run as the boinc user for safety and so intermediate files are appropriately owned
		# first need to grant access to the portage tempdir
		local PERFDATA_BOINC_TMPDIR="$(mktemp -d)"
		chown boinc "${PERFDATA_BOINC_TMPDIR:?}"
		chmod o+x "${PORTAGE_BUILDDIR:?}"
		# generate prof
		local PERFDATA_PROFILE_BOINC="${PERFDATA_BOINC_TMPDIR:?}/perfdata.prof"
		TMPDIR="${PERFDATA_BOINC_TMPDIR}" runuser -u boinc -- \
			perfdata-mkprof "${SYSROOT%/}${PERFDATA_PROFILE_DIR_BOINC}" --binary "${SYSROOT%/}/${CMDOCK_EXE}" \
				--output "${PERFDATA_PROFILE_BOINC}" || die "perfdata-mkprof failed"
		# copy prof for access later in the build
		PERFDATA_PROFILE="${T}/perfdata.prof"
		mv --no-target-directory "${PERFDATA_PROFILE_BOINC}" "${PERFDATA_PROFILE}"
	fi
}

src_prepare() {
	default
	python_fix_shebang "${S}"/bin
}

src_configure() {
	if use clang; then
		tc-use-clang
	elif tc-is-clang; then
		# when USE="-clang" but CXX="clang++" we cannot rely on BDEPEND
		# continue anyway as long as the build dependencies are installed
		# if these were runtime dependencies this would not be safe
		for P in ${BDEPEND_CLANG}; do require_version -b "${P}"; done
		use pgo && for P in ${BDEPEND_CLANG_PGO}; do require_version -b "${P}"; done
	fi

	if tc-is-gcc && tc-is-lto && ! use pgo; then
		ewarn "filtering gcc lto because it degrades performance without pgo"
		filter-lto
	fi

	if use pgo; then
		# do not assume all code paths are exercised during pgo training
		tc-is-clang && PGO_FLAGS_DEFAULT="-fno-profile-sample-accurate" || PGO_FLAGS_DEFAULT="-fprofile-partial-training"
		export CFLAGS="${PGO_FLAGS_DEFAULT} ${CFLAGS}"
		export CXXFLAGS="${PGO_FLAGS_DEFAULT} ${CXXFLAGS}"
	fi

	# perfdata is an implementation of sampling profile guided optimization
	# see https://clang.llvm.org/docs/UsersManual.html#using-sampling-profilers

	if use perfdata-gen; then
		# the clang documentation claims -g1 (aka -gline-tables-only) is sufficient but...
		# this level gives warnings about inconsistent dwarf info in 22.86%(72/315) of functions
		tc-is-clang && append-flags '-g2' || append-flags '-g1'
	fi

	if use perfdata-use; then
		# clang flag has more specific name -fprofile-sample-use but accepts -fauto-profile for gcc compat
		append-flags "-fauto-profile=\"${PERFDATA_PROFILE}\""
		# todo: does this help or hurt? on by default?
		tc-is-clang && append-flags "-fsample-profile-use-profi"
	fi

	use cpu_flags_x86_sse2 || append-cppflags "-DBUNDLE_NO_SSE"

	# very weird directory layout
	local emesonargs=(
		--prefix="${INSTALL_PREFIX}"
		$(meson_use apidoc)
		$(meson_use doc)
		$(meson_use test tests)
		-Ddocdir="${EPREFIX}"/usr/share/doc/${PF}
	)
	meson_src_configure
}

src_compile() {
	if use pgo; then
		meson configure -Db_pgo=generate "${BUILD_DIR}"
	fi

	meson_src_compile

	if use pgo; then
		# generate pgo profile with real project data
		# run only for a few minutes because the full job would take many hours
		timeout --signal=INT --preserve-status "${PGO_TIMEOUT:-10m}" \
			"${BUILD_DIR}/cmdock" -c -j 1 -b 1 -x -r "${FILESDIR}/pgo/target.prm" -p "${S}/data/scripts/dock.prm" \
			-f "${FILESDIR}/pgo/htvs.ptc" -i "${FILESDIR}/pgo/ligands.sdf" -o "${T}/pgo-docking_out"

		if tc-is-clang; then
			llvm-profdata merge --instr "${BUILD_DIR}"/*.profraw --output="${BUILD_DIR}/default.profdata" || die "llvm-profdata failed"
		fi

		# rebuild using the pgo profile
		meson configure -Db_pgo=use "${BUILD_DIR}"
		meson_src_compile
	fi
}

src_install() {
	meson_src_install
	python_optimize "${D}${INSTALL_PREFIX}"/bin

	if use boinc; then
		doappinfo "${FILESDIR}"/app_info_${PV}.xml
		dowrapper cmdock-l

		# install cmdock executable
		if use perfdata-gen; then
			# todo: would it make sense to use boinc-wrapper config instead of shell script?
			CMDOCK_EXE_WRAPPER="${T}/perfdata-cmdock"
			<<EOF cat > "${CMDOCK_EXE_WRAPPER}"
#!/bin/sh
source /etc/profile.env # make sure llvm tools are in path
export PERFDATA_PROFILE_DIR="${PERFDATA_PROFILE_DIR_BOINC}"
export PERFDATA_CONVERT_PROF=true
exec perfdata "${CMDOCK_EXE}" "\${@}"
EOF
			exeinto "$(get_project_root)"
			exeopts --owner root --group boinc
			newexe "${CMDOCK_EXE_WRAPPER}" cmdock-${PV}
		else
			# link cmdock executable
			# this used to copy cmdock into the project directory...
			# but this can cause failures after rebuilding the package and restarting boinc
			# because the new cmdock binary might not match up with libcmdock.so
			# could copy ${INSTALL_PREFIX} to the project directory so that each task gets a stable snapshot
			# but this would require listing every single file in app_info.xml
			dosym -r "${CMDOCK_EXE}" "$(get_project_root)/cmdock-${PV}"
		fi

		# install a blank file
		touch "${T}"/docking_out || die
		insinto "$(get_project_root)"
		insopts --owner root --group boinc
		doins "${T}"/docking_out
	fi
}

pkg_postinst() {
	optfeature "sdtether.py and sdrmsd.py scripts" "dev-python/numpy sci-chemistry/openbabel[python]"
	use boinc && boinc-app_pkg_postinst
}

pkg_postrm() {
	use boinc && boinc-app_pkg_postrm
}
