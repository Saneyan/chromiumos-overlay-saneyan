EAPI=5

DESCRIPTION="The saneyan meta package to pull in driver/tool dependencies"

LICENSE="BSD-Google"
SLOT="0"
KEYWORDS="-* amd64"
IUSE="kvm"

DEPEND=""
RDEPEND="${DEPEND}
	kvm? (
		app-emulation/qemu
		net-misc/bridge-utils
	)
"
