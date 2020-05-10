# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit cmake-utils

PYTHON_COMPAT=( python{2_7,3_7} )
inherit python-r1

GH_REPO="https://github.com/OpenKinect/${PN}"
DESCRIPTION="Drivers and libraries for the Xbox Kinect device"
HOMEPAGE="${GH_REPO}"

SLOT="0"
KEYWORDS="~amd64"
LICENSE="Apache-2.0 GPL-2"
IUSE="bindist +c_sync +cpp doc examples +fakenect opencv openni2"

if [[ "${PV}" == "9999" ]] ; then
  inherit git-r3
  KEYWORDS=""
  EGIT_REPO_URI="${GH_REPO}"
else
  SRC_URI="${GH_REPO}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
fi

COMMON_DEP="
  virtual/libusb:1
  examples? ( media-libs/freeglut
              virtual/opengl )
  opencv? ( media-libs/opencv )
  ${PYTHON_DEPS}
  $(python_gen_cond_dep 'dev-python/numpy[${PYTHON_USEDEP}]')
"
BDEPEND="
  !bindist? ( dev-lang/python:2 )
  doc? ( app-doc/doxygen )
  dev-util/cmake
  sys-apps/sed
  virtual/pkgconfig
"
DEPEND="${COMMON_DEP}
  $(python_gen_cond_dep 'dev-python/cython[${PYTHON_USEDEP}]')
"
RDEPEND="${COMMON_DEP}"

src_prepare() {
  sed -i "s|PROJECT_LIBRARY_INSTALL_DIR \"lib\"|PROJECT_LIBRARY_INSTALL_DIR \"$(get_libdir)\"|" "${S}/cmake_modules/SetupDirectories.cmake" || die "sed failed"
  cmake-utils_src_prepare
}

src_configure() {
  local mycmakeargs=(
    -DBUILD_REDIST_PACKAGE="$(usex bindist)"
    -DBUILD_C_SYNC="$(usex c_sync)"
    -DBUILD_CPP="$(usex cpp)"
    -DBUILD_EXAMPLES="$(usex examples)"
    -DBUILD_FAKENECT="$(usex fakenect)"
    -DBUILD_CV="$(usex opencv)"
    -DBUILD_OPENNI2_DRIVER="$(usex openni2)"
    -DBUILD_PYTHON2="$(usex python_targets_python2_7)"
    -DPython2_EXACTVERSION="$(use python_targets_python2_7 && python2.7 -c "import platform ; print(platform.python_version())")"
    -DBUILD_PYTHON3="$(usex python_targets_python3_7)"
    -DPython3_EXACTVERSION="$(use python_targets_python3_7 && python3.7 -c "import platform ; print(platform.python_version())")"
  )
  cmake-utils_src_configure
}

src_install() {
  cmake-utils_src_install

  # udev rules
  insinto "/lib/udev/rules.d/"
  doins "${S}/platform/linux/udev/51-kinect.rules"

  # documentation
  dodoc README.md
  if use doc; then
    cd doc
    doxygen || ewarn "doxygen failed"
    dodoc -r html || ewarn "dodoc failed"
    cd -
  fi
}

pkg_postinst() {
  if ! use bindist; then
    ewarn "The bindist USE flag is disabled. Resulting binaries may not be legal to re-distribute."
  fi
  elog "Make sure your user is in the 'video' group"
  elog "Just run 'gpasswd -a <USER> video', then have <USER> re-login."
}
