# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit eutils desktop

DESCRIPTION="VS Code without MS branding/telemetry/licensing"
HOMEPAGE="https://vscodium.com/"
LICENSE="MIT"

BUILDARCH="x64"
ELECTRON_VERSION="6.1.6"
ELECTRON_ZIP="electron-v${ELECTRON_VERSION}-linux-${BUILDARCH}.zip"
ELECTRON_FFMPEG_ZIP="ffmpeg-v${ELECTRON_VERSION}-linux-${BUILDARCH}.zip"

SRC_URI="
  https://github.com/VSCodium/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
  https://github.com/microsoft/vscode/archive/${PV}.tar.gz -> vscode-${PV}.tar.gz
  https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/${ELECTRON_ZIP}
  !system-ffmpeg? ( https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/${ELECTRON_FFMPEG_ZIP} )
"

RESTRICT="strip network-sandbox"
SLOT="0"
KEYWORDS="-* ~amd64" # todo: other arches
IUSE="minify +system-ffmpeg"

COMMON_DEPEND=""
BDEPEND="
  app-misc/jq
  app-shells/bash
  net-libs/nodejs[npm]
  sys-apps/grep
  sys-apps/sed
  sys-apps/yarn
  sys-devel/patch
"
DEPEND="${COMMON_DEPEND}
  >=app-crypt/libsecret-0.18.5:0[crypt]
"
RDEPEND="${COMMON_DEPEND}
  system-ffmpeg? ( media-video/ffmpeg[chromium] )
  app-accessibility/at-spi2-core
  app-accessibility/at-spi2-atk:2
  dev-libs/atk
  dev-libs/expat
  dev-libs/glib:2
  dev-libs/nspr
  =dev-libs/nss-3*
  media-libs/alsa-lib
  net-print/cups
  =sys-apps/dbus-1*
  sys-apps/util-linux
  sys-libs/glibc
  x11-libs/cairo
  x11-libs/gdk-pixbuf:2
  x11-libs/gtk+:3
  x11-libs/libXScrnSaver
  x11-libs/libXrandr
  x11-libs/libXtst
  x11-libs/libXi
  x11-libs/libXfixes
  x11-libs/libXdamage
  x11-libs/libXcursor
  x11-libs/libX11
  x11-libs/libXrender
  x11-libs/libXcomposite
  x11-libs/libXext
  x11-libs/pango
"

# todo: are any of these necessary?
OLD_EXTRA_RDEPEND="
  >=app-crypt/libsecret-0.18.5:0[crypt]
  >=dev-libs/libdbusmenu-16.04.0
  >=media-libs/libpng-1.2.46:0
  >=x11-libs/libnotify-0.7.7:0
"

S_VSCODE="${S}/vscode"

src_unpack() {
  unpack "${P}.tar.gz"
  unpack "vscode-${PV}.tar.gz"
  mv --no-target-directory "vscode-${PV}" "${S_VSCODE}" || die "vscode move failed"

  mkdir -p "${HOME}/.cache/electron/"
  mkdir -p "${T}/gulp-electron-cache/atom/electron/"
  ln "${DISTDIR}/${ELECTRON_ZIP}" "${HOME}/.cache/electron/"
  ln "${DISTDIR}/${ELECTRON_ZIP}" "${T}/gulp-electron-cache/atom/electron/"
  if ! use system-ffmpeg ; then
    ln "${DISTDIR}/${ELECTRON_FFMPEG_ZIP}" "${HOME}/.cache/electron/"
    ln "${DISTDIR}/${ELECTRON_FFMPEG_ZIP}" "${T}/gulp-electron-cache/atom/electron/"
  fi
}

src_prepare() {
  export npm_config_scripts_prepend_node_path="auto"
  yarn global add node-gyp

  # create a fake git directory to stop husky searching up the fs tree and trying to write outside the sandbox
  mkdir "${WORKDIR}/.git"

  # remove all build calls so we can make our own instead
  # todo: make a PR to extract patching from build.sh to prepare.sh
  sed -i "s|. ../create_appimage.sh|:|" ./build.sh || die
  sed -i "s|yarn gulp.*|:|" ./build.sh || die

  if use system-ffmpeg; then
    # prevent downloading an extra version of libffmpeg.so during the build
    for file in "${S_VSCODE}/build/lib/electron.js" "${S_VSCODE}/build/lib/electron.ts" "${S_VSCODE}/build/gulpfile.vscode.js"; do
      sed -i "s|ffmpegChromium: true|ffmpegChromium: false|" "${file}" || die "setting ffmpegChromium failed"
    done
  fi

  default
}

src_compile () {
  export TRAVIS_OS_NAME="linux"
  export SHOULD_BUILD="yes"
  export BUILDARCH
  ./build.sh

  # todo: disable upgrade URL since versions will be managed by portage

  cd "${S_VSCODE}"
    export NODE_ENV="production" # todo: necessary?
	  # the minify step is very expensive in RAM and CPU time, so make it optional
	  use minify && GULP_TARGET="vscode-linux-${BUILDARCH}-min" || GULP_TARGET="vscode-linux-${BUILDARCH}"
    yarn gulp "${GULP_TARGET}" || die "gulp build failed"
  cd -
}

RELTARGET="opt/${PN}"

QA_PRESTRIPPED="${RELTARGET}/codium"
QA_PREBUILT="${RELTARGET}}/codium"

src_install() {
  dodir "/opt"
  # using doins -r would strip executable bits from all binaries
  cp -pPR --no-target-directory "${S}/VSCode-linux-${BUILDARCH}" "${ED}/${RELTARGET}" || die "file copy failed"
  if use system-ffmpeg; then
    dosym "${EPREFIX}/usr/lib64/chromium/libffmpeg.so" "/${RELTARGET}/libffmpeg.so" || die "ffmpeg.so symlink failed"
  fi
  dosym "${EPREFIX}/${RELTARGET}/bin/codium" "/usr/bin/codium" || die "codium symlink failed"
  newicon "${S}/src/resources/linux/code.png" "${PN}.png"
  make_desktop_entry "codium" "VSCodium" "${PN}" "Development;IDE"
}