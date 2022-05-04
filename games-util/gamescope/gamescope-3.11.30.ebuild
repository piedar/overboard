# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

MYMESONARGS="--wrap-mode nofallback --force-fallback-for libliftoff"
inherit meson

DESCRIPTION="SteamOS session compositing window manager"
HOMEPAGE="https://github.com/Plagman/gamescope"
LICENSE="BSD-2"
LICENSE="${LICENSE} MIT" # from bundled libliftoff

SLOT="0"
KEYWORDS="~amd64"
IUSE="+pipewire"

if [[ "${PV}" == "9999" ]]; then
  EGIT_REPO_URI="https://github.com/Plagman/gamescope.git"
  EGIT_SUBMODULES=( subprojects/libliftoff )
  inherit git-r3
  KEYWORDS=""
else
  LIBLIFTOFF_COMMIT="378ccb4f84a2473fe73dbdc56fe35a0d2ee661cc"
  SRC_URI="
    https://github.com/Plagman/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz
    https://gitlab.freedesktop.org/emersion/libliftoff/-/archive/${LIBLIFTOFF_COMMIT}.tar.gz -> libliftoff-${LIBLIFTOFF_COMMIT}.tar.gz
  "
fi

DEPEND="
  dev-libs/stb
  >=dev-libs/wayland-protocols-1.17
  gui-libs/wlroots:0/15[X]
  media-libs/libsdl2
  media-libs/vulkan-loader
  pipewire? ( =media-video/pipewire-0.3* )
  sys-libs/libcap
  x11-libs/libX11
  x11-libs/libXcomposite
  x11-libs/libXdamage
  >=x11-libs/libdrm-2.4.105
  x11-libs/libXext
  x11-libs/libXfixes
  x11-libs/libxkbcommon
  x11-libs/libXrender
  x11-libs/libXres
  x11-libs/libXtst
  x11-libs/libXxf86vm
"
BDEPEND="
  >=dev-libs/wayland-protocols-1.17
  dev-util/glslang
  >=dev-util/meson-0.58.0
  dev-util/vulkan-headers
  virtual/pkgconfig
"

PATCHES=(
  "${FILESDIR}/3.11.30-system-stb.patch"
)

src_prepare() {
  if ! [[ "${PV}" == "9999" ]]; then
    rmdir subprojects/libliftoff
    mv "../libliftoff-${LIBLIFTOFF_COMMIT}" subprojects/libliftoff || die
  fi
  default
}

src_configure() {
  local emesonargs=(
    $(meson_feature pipewire)
  )
  meson_src_configure
}

src_install() {
  meson_src_install --skip-subprojects
}
