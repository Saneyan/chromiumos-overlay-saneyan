# Copyright 2016 TADOKORO Saneyuki. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=5

DESCRIPTION="The saneyan meta package to pull in driver/tool dependencies"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="-* amd64"
IUSE="kvm neovim"

DEPEND=""
RDEPEND="${DEPEND}
	kvm? (
		app-emulation/qemu
		net-misc/bridge-utils
	)
	neovim? ( app-editors/neovim )
"

#S=$WORKDIR

#src_install() {
#	dosbin "${FILESDIR}/kvmc"
#	insinto "/etc/init"
#	doins "${FILESDIR}"/upstart/*
#}
