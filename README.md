# chromiumos-overlay-saneyan

The Chromium OS overlay for saneyan dev environment.
This overlay bundles dev packages and enables KVM for Chromium OS.

## Installation

**Before installing this overlay, you must prepare to build Chromium OS and get the source code.**

Place this overlay into `~/chromiumos/src/overlays`. Then, the dir name must be `overlay-saneyan`.

```
git clone https://github.com/Saneyan/chromiumos-overlay-saneyan.git overlay-saneyan
mv overlay-saneyan ~/chromiumos/src/overlays
```

Add `saneyan` to $ALL\_BOARDS list in `~/chromiumos/src/third_party/chromiumos-overlay/eclass/cros-board.eclass` so that cros can setup and bulid an image for the board.

## Build

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
./build_image dev --boot_args="noinitrd lsm.module_locking=0 disablevmx=off"
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
