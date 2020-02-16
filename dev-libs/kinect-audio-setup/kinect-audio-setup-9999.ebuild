# Copyright 1999-2020 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit git-r3

MSI_FILE="KinectSDK-v1.0-beta2-x86.msi"
DESCRIPTION="Tools to enable audio input from the Microsoft Kinect sensor device"
HOMEPAGE="https://git.ao2.it/${PN}.git"
EGIT_REPO_URI="https://git.ao2.it/${PN}.git"
SRC_URI="https://download.microsoft.com/download/F/9/9/F99791F2-D5BE-478A-B77A-830AD14950C3/${MSI_FILE}"
RESTRICT="mirror"

LICENSE="BSD-2 WTFPL-2"
SLOT="0"
KEYWORDS=""
IUSE=""

COMMON_DEP="
  virtual/libusb:1
  virtual/udev
"
BDEPEND="
  app-arch/p7zip
"
DEPEND="${COMMON_DEP}"
RDEPEND="${COMMON_DEP}"

src_unpack() {
  default
  git-r3_src_unpack
  7z e -y -r "${DISTDIR}/${MSI_FILE}" "UACFirmware.*" -o"${S}/"
}

src_install() {
  dodoc NEWS README
  emake DESTDIR="${D}" PREFIX="/usr" install

  # install firmware
  FIRMWARE_RELDIR="lib/firmware/kinect"
  insinto "/${FIRMWARE_RELDIR}"
  insopts -m644
  newins UACFirmware.* "UACFirmware"

  # patch udev rules to match the installed result
  # upstream Makefile uses the same DESTDIR for patching and loading but we need to account for EPREFIX
  FIRMWARE_PATH="${EPREFIX}/${FIRMWARE_RELDIR}/UACFirmware"
  LOADER_PATH="${EPREFIX}/usr/sbin/kinect_upload_firmware"
  RULES_FILE="55-kinect_audio.rules"
  cp "contrib/${RULES_FILE}.in" "${RULES_FILE}"
  ./kinect_patch_udev_rules "${FIRMWARE_PATH}" "${LOADER_PATH}" "${RULES_FILE}"

  # install udev rules
  insinto "/lib/udev/rules.d/"
  insopts -m644
  doins "${RULES_FILE}"
}

pkg_postinst() {
  udevadm control --reload-rules
}
