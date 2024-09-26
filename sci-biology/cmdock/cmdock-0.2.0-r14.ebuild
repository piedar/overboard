# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# notes about optimization
	# CXXFLAGS="-O3" recommended
	# LTO recommended with clang, but hit or miss with gcc

	# USE=pgo implements traditional compile => train => recompile
	# trains on static data from an actual cmdock boinc job
	# env PGO_TIMEOUT=2h to change training time limit

	# perfdata-sample implements live sampling PGO
	# see https://clang.llvm.org/docs/UsersManual.html#using-sampling-profilers
	# clang only - gcc tooling is not really usable
	# may require special CPU features for branch sampling
	# traditional pgo builds can be sampled but not both applied to the same build
	# can be repeated indefinitely, as any build with debug symbols can be sampled
	# adds about 10% runtime sample conversion overhead (todo: reduce)
#

EAPI=8

PYTHON_COMPAT=( python3_{11..12} )
BOINC_APP_OPTIONAL=1
inherit boinc-app flag-o-matic meson optfeature python-any-r1 systemd toolchain-funcs toolchain-override

DESCRIPTION="Program for docking ligands to proteins and nucleic acids"
HOMEPAGE="https://gitlab.com/Jukic/cmdock"
SRC_URI="https://gitlab.com/Jukic/${PN}/-/archive/v${PV}/${PN}-v${PV}.tar.bz2"
S="${WORKDIR}/${PN}-v${PV}"

LICENSE="LGPL-3 ZLIB"
SLOT="0/${PV}"
KEYWORDS="~amd64"
# todo: make openmp optional
IUSE="apidoc clang cpu_flags_x86_sse2 doc perfdata-sample-gen perfdata-sample-use pgo test"
REQUIRED_USE="
	perfdata-sample-use? ( clang !pgo )
"
RESTRICT="perfdata-sample-gen? ( strip ) !test? ( test )"

RDEPEND="
	perfdata-sample-gen? (
		app-alternatives/sh
		=dev-util/perfdata-0.15*
	)
"
DEPEND="
	dev-cpp/eigen:3
	>=dev-cpp/indicators-2.3-r1
	>=dev-cpp/pcg-cpp-0.98.1_p20210406-r1
	=dev-libs/cxxopts-3.0*
	perfdata-sample-use? (
		boinc? ( sci-biology/cmdock[boinc?] )
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
	perfdata-sample-use? (
		boinc? (
			clang? ( ${BDEPEND_CLANG_PGO} )
			sys-apps/findutils
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
	"${FILESDIR}/${PN}-0.2.0-fix-exit-gracefully-on-SIGTERM.patch"
)

DOCS=( README.md changelog.md )

BOINC_MASTER_URL="https://www.sidock.si/sidock/"
BOINC_INVITATION_CODE="Crunch_4Science"
BOINC_APP_HELPTEXT=\
"The easiest way to do something useful with this application
is to attach it to SiDock@home BOINC project."

readonly INSTALL_PREFIX="${EPREFIX}/opt/${P}"
readonly CMDOCK_EXE="${INSTALL_PREFIX:?}/bin/cmdock"
readonly CMDOCK_LIB="${INSTALL_PREFIX:?}/lib/libcmdock.so"
: "${PERFDATA_PROFILE_DIR_BOINC:=${EPREFIX%/}$(get_boincdir)/.cache/perfdata/cmdock}"

boinc-app_add_deps --wrapper

python_check_deps() {
	use doc || return 0

	python_has_version "dev-python/sphinx[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/insipid-sphinx-theme[${PYTHON_USEDEP}]"
}

foreach_wrapper_job() {
	sed -e "s:@PREFIX@:${INSTALL_PREFIX:?}:g" -i "${1}" || die
}

pkg_setup() {
	python-any-r1_pkg_setup

	if [ "${MERGE_TYPE}" != 'binary' ] && use boinc; then
		if use perfdata-sample-use && [ -z "${PERFDATA_PROFILE_SAMPLE}" ]; then
			# collect prof files created by cmdock running under boinc
			PERFDATA_PROFILE_SAMPLE="${T}/perfdata.prof"
			readarray -d '' PROF_FILES < <(find "${SYSROOT%/}/${PERFDATA_PROFILE_DIR_BOINC}" -type f -name '*.prof' -print0 | sort --unique --zero-terminated)
			llvm-profdata merge --sample ${PROF_FILES[@]} --output="${PERFDATA_PROFILE_SAMPLE}" || die "llvm-profdata failed"
		fi
	fi
}

src_prepare() {
	default
	python_fix_shebang "${S}"/bin
}

prepend-flags() {
	export CFLAGS="${@} ${CFLAGS}"
	export CXXFLAGS="${@} ${CXXFLAGS}"
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
		ewarn "gcc lto might degrade performance without pgo"
	fi

	use pgo && tc-is-gcc && append-flags "-fprofile-prefix-path=${S}"

	if use pgo || use perfdata-sample-use; then
		# do not assume all code paths are exercised during pgo training
		tc-is-clang && prepend-flags '-fno-profile-sample-accurate' || prepend-flags '-fprofile-partial-training'
	fi

	if use perfdata-sample-gen; then
		# seems like traditional AFDO used '-gline-tables-only -fdebug-info-for-profiling'
		# but now CSSPGO with pseudo-probe is the new hotness
		tc-is-clang && append-flags '-g2 -fpseudo-probe-for-profiling' || append-flags '-g1'
		# frame pointer required for profiling, at least until llvm-profgen can handle dwarf
		append-flags '-fno-omit-frame-pointer'
	fi

	if use perfdata-sample-use; then
		# clang flag has more specific name -fprofile-sample-use but accepts -fauto-profile for gcc compat
		append-flags "-fauto-profile=${PERFDATA_PROFILE_SAMPLE}"
		# probes must also be used when consuming the sample, so that llvm can verify checksums and probe mappings
		tc-is-clang && append-flags '-fpseudo-probe-for-profiling'
		# todo: does this help or hurt? on by default?
		tc-is-clang && prepend-flags "-fsample-profile-use-profi"
	fi

	use cpu_flags_x86_sse2 || append-cppflags "-DBUNDLE_NO_SSE"

	# very weird directory layout
	local emesonargs=(
		--prefix="${INSTALL_PREFIX:?}"
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
		meson_src_compile

		# generate pgo profile with real project data
		# run only for a few minutes because the full job would take many hours
		timeout --signal=INT --preserve-status "${PGO_TIMEOUT:-10m}" \
			"${BUILD_DIR}/cmdock" -c -j 1 -b 1 -r "${FILESDIR}/pgo/target.prm" -p "${S}/data/scripts/dock.prm" \
			-f "${FILESDIR}/pgo/htvs.ptc" -i "${FILESDIR}/pgo/ligands.sdf" -o "${T}/pgo-docking_out"

		if tc-is-clang; then
			# collect profraw in ${S} from pgo run
			# might also be profraw in ${BUILD_DIR} when USE=test but probably not worth collecting
			llvm-profdata merge --instr "${S}"/*.profraw --output="${BUILD_DIR}/default.profdata" || die "llvm-profdata failed"
		fi

		# rebuild using the pgo profile
		meson configure -Db_pgo=use "${BUILD_DIR}"
	fi

	meson_src_compile
}

_gen_cmdock_wrapper() {
	cat <<EOF
#!/bin/sh
exec "${CMDOCK_EXE}" "\${@}"
EOF
}

src_install() {
	meson_src_install
	python_optimize "${D}${INSTALL_PREFIX:?}"/bin

	if use boinc; then
		boinc_install_appinfo "${FILESDIR}/app_info_${PV}.xml"
		boinc_install_wrapper cmdock-l_wrapper \
			"${FILESDIR}/cmdock-l_job_${PV}.xml" "cmdock-l_job.xml"

		# install cmdock wrapper script
		# this could instead be a copy of the binary like guru does it, or a symlink
		# but boinc checks the file size and complains if it changes
		# this script allows hot swapping the binary without restarting boinc
		CMDOCK_EXE_WRAPPER="${T}/perfdata-cmdock"
		_gen_cmdock_wrapper > "${CMDOCK_EXE_WRAPPER}"
		exeinto "$(get_project_root)"
		exeopts --owner root --group boinc
		newexe "${CMDOCK_EXE_WRAPPER}" cmdock

		# install a blank file
		insinto "$(get_project_root)"
		insopts -m 0644 --owner root --group boinc
		newins - docking_out

		if use perfdata-sample-gen; then
			insinto "/lib/systemd/system/boinc-client.service.d/"
			doins "${FILESDIR}/zz-boinc-client-perfdata.conf"

			systemd_dounit "${FILESDIR}/perfdata-cmdock@.service"
			systemd_enable_service "boinc-client.service" "perfdata-cmdock@.service"
		fi
	fi
}

pkg_postinst() {
	optfeature "sdtether.py and sdrmsd.py scripts" "dev-python/numpy sci-chemistry/openbabel[python]"
	use boinc && boinc-app_pkg_postinst
}

pkg_postrm() {
	use boinc && boinc-app_pkg_postrm
}
