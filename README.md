# chromiumos-overlay-saneyan

The Chromium OS overlay for saneyan dev environment.<br>
This overlay bundles dev packages and enables KVM for Chromium OS.

## Installation

**Before installing this overlay, you must prepare to build Chromium OS and get the source code.**

Place the overlay into `~/chromiumos/src/overlays`. Then, the dir name must be `overlay-saneyan`.

```
git clone https://github.com/Saneyan/chromiumos-overlay-saneyan.git overlay-saneyan
mv overlay-saneyan ~/chromiumos/src/overlays
```

Create and check out a new branch in each of portage-stable and chromiumos-overlay repository.

```
cd ~/chromiumos/src/third_party/portage-stable
repo start saneyan/master .
cd ../chromiumos-overlay
repo start saneyan/master .
```

#### Edit eclass and ebuild

Add `saneyan` to $ALL\_BOARDS list in `~/chromiumos/src/third_party/chromiumos-overlay/eclass/cros-board.eclass` so that cros can setup and bulid an image for the board.

Add the following package names to $CROS\_COMMON\_RDEPEND list in `~/chromiumos/src/third_party/chromiumos-overlay/virtual/target-chromium-os/target-chromium-os-1.ebuild` to install additional packages.<br>

```
app-shells/zsh
app-shells/zsh-completions
app-misc/tmux
dev-vcs/git
kvm? (
  app-emulation/qemu
  net-misc/bridge-utils
)
neovim? ( app-editors/neovim )
```

Do not forget add use flags to IUSE variable.

```
IUSE="${IUSE} kvm neovim"
```

**Make sure the revision number of the ebuild has been incremented.**

#### Licensing

The `app-shells/zsh-completions` uses BSD license but not BSD-Google. So you must copy the copyright attribution to `~/chromiumos/src/third_party/chromiumos-overlay/licences/copyright-attribution` from the overlay.

```
cp -r ../../overlays/overlay-saneyan/licenses/copyright-attribution/app-shells ./licenses/copyright-attribution
```

#### Fix crosutils (udev)

You should fix mtools to avoid mcopy's flock failure for build\_image.

```
repo download --cherry-pick chromiumos/platform/crosutils 303962/1
```

#### USE flag

 * `kvm`: Enable KVM and install qemu package (containing qemu-system-x86\_64 command, disabling USB passthrough).
 * `neovim`: Install Neovim that's a refactor in the tradition of Vim (accepting ~amd64 keyword). Do not forget Portage must support EAPI 6, or the LPeg which Neovim depends is never installed.

## Build

Enter chroot with cros\_sdk.

```
cros_sdk
```

This command needs to run once.

```
./setup_board --board=saneyan
```

You need to build packages before building an image.

```
./build_packages --board=saneyan
```

After that, let's build an image and copy onto a USB drive.

```
./build_image --board=saneyan --noenable_rootfs_verification --boot_args="noinitrd lsm.module_locking=0 disablevmx=off" dev
cros flash usb:///dev/sdx saneyan/latest
```

## Setup

After staring up, add the kvm\_intel module to Linux kernel and check installation with lsmod.

```
sudo modprobe kvm_intel
lsmod | grep kvm_intel # You will see it.
```

### Prepare Virtual Machine (CoreOS)

Get the wrapper shell script and the disk image.

```
sudo mkdir -p /usr/local/q/coreos
cd /usr/local/q/coreos
COREOS_URL="https://stable.release.core-os.net/amd64-usr/current/"
COREOS_DIST="coreos_production_qemu"
wget $COREOS_URL/$COREOS_DIST.sh
wget $COREOS_URL/$COREOS_DIST.sh.sig
wget $COREOS_URL/${COREOS_DIST}_image.img.bz2
wget $COREOS_URL/${COREOS_DIST}_image.img.bz2.sig
gpg --verify $COREOS_DIST.sh.sig
gpg --verify ${COREOS_DIST}_image.img.bz2.sig
bzip2 -d ${COREOS_DIST}_image.img.bz2
chmod +x $COREOS_DIST.sh
```

Run the virtual machine and connect via SSH.

```
./coreos_production_qemu.sh -a ~/.ssh/authorized_keys -- -nographic
ssh -l -p 2222 localhost
```
